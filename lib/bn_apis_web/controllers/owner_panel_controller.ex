defmodule BnApisWeb.OwnerPanelController do
  use BnApisWeb, :controller

  alias BnApis.Orders
  alias BnApis.Packages
  alias BnApis.Orders.{Order, MatchPlus, MatchPlusPackage}
  alias BnApis.Memberships.{MatchPlusMembership, MembershipOrder}
  alias BnApis.Accounts.{EmployeeRole, Credential}
  alias BnApis.Helpers.{Connection}

  action_fallback(BnApisWeb.FallbackController)

  plug :access_check,
       [
         allowed_roles: [
           EmployeeRole.super().id,
           EmployeeRole.admin().id,
           EmployeeRole.owner_supply_admin().id,
           EmployeeRole.owner_supply_operations().id,
           EmployeeRole.broker_admin().id
         ]
       ]
       when action in [
              :get_active_memberships_count,
              :get_pg_new_and_autopay_memberships_count,
              :get_membership_details,
              :payments_summary
            ]

  plug :access_check,
       [
         allowed_roles: [
           EmployeeRole.super().id
         ]
       ]
       when action in [
              :create_offline_payment
            ]

  defp access_check(conn, options) do
    logged_in_user = Connection.get_employee_logged_in_user(conn)
    ## this can support multiple access_roles like has to be super & mobile number...
    Enum.reduce(Keyword.keys(options), conn, fn
      :allowed_roles, conn -> if logged_in_user.employee_role_id in options[:allowed_roles], do: conn, else: conn |> unauthorize()
      :allowed_numbers, conn -> if logged_in_user.phone_number in options[:allowed_numbers], do: conn, else: conn |> unauthorize()
    end)
  end

  defp unauthorize(conn), do: conn |> send_resp(401, "Sorry, You are not authorized to take this action!") |> halt()

  def get_active_memberships_count(conn, params) do
    total_paytm_active_membs_count = MatchPlusMembership.get_match_plus_count(params)
    total_razor_pay_active_subs_count = MatchPlus.get_match_plus_count(params)

    data = %{
      "paytm_active_memberships_count" => total_paytm_active_membs_count,
      "razorpay_active_subscriptions_count" => total_razor_pay_active_subs_count
    }

    conn
    |> put_status(:ok)
    |> json(%{data: data})
  end

  def get_pg_new_and_autopay_memberships_count(conn, params) do
    # city_id = params["city_id"]
    # time_range_query = params["time_range_query"]
    {
      total_paytm_new_membs_count,
      total_paytm_cancelled_membs_count,
      total_paytm_renewed_paytm_membs_count,
      total_paytm_not_renewed_paytm_membs_count
    } = MatchPlusMembership.get_new_and_cancelled_and_renewed_memberships_count(params)

    {total_razorpay_new_subs_count, total_razorpay_cancelled_subs_count} = MatchPlus.get_new_and_cancelled_subscriptions_count(params)

    total_paytm_renewed_membs = 0

    data = %{
      "total_memberships_renewed" => total_paytm_renewed_membs,
      "paytm_new_memberships_count" => total_paytm_new_membs_count,
      "razorpay_new_subscriptions_count" => total_razorpay_new_subs_count,
      "paytm_cancelled_memberships_count" => total_paytm_cancelled_membs_count,
      "razorpay_cancelled_subscriptions_count" => total_razorpay_cancelled_subs_count,
      "paytm_renewed_memberships_count" => total_paytm_renewed_paytm_membs_count,
      "paytm_not_renewed_memberships_count" => total_paytm_not_renewed_paytm_membs_count
    }

    conn
    |> put_status(:ok)
    |> json(%{data: data})
  end

  def get_membership_details(conn, params) do
    payment_gateway = params["payment_gateway"]

    case payment_gateway do
      "billdesk" ->
        {user_packages, total_count, has_more_packages} = Packages.get_owner_panel_data(params)

        conn
        |> put_status(:ok)
        |> json(%{
          data: user_packages,
          total_count: total_count,
          has_more_memberships: has_more_packages
        })

      "paytm" ->
        {paytm_membs_list, total_paytm_membs_count, has_more_paytm_memberships} = MatchPlusMembership.get_owner_panel_data(params)

        conn
        |> put_status(:ok)
        |> json(%{
          data: paytm_membs_list,
          total_count: total_paytm_membs_count,
          has_more_memberships: has_more_paytm_memberships
        })

      "razorpay" ->
        {razorpay_membs_list, total_razorpay_membs_count, has_more_razorpay_memberships} = MatchPlus.get_owner_panel_data(params)

        conn
        |> put_status(:ok)
        |> json(%{
          data: razorpay_membs_list,
          total_count: total_razorpay_membs_count,
          has_more_memberships: has_more_razorpay_memberships
        })
    end
  end

  def get_membership_orders(conn, params) do
    data = MembershipOrder.get_orders_by_membership_id(params["id"])

    conn
    |> put_status(:ok)
    |> json(%{data: data})
  end

  def get_razorpay_orders(conn, %{"broker_phone_number" => broker_phone_number}) do
    data = Order.get_orders_by_phone_number(broker_phone_number)

    conn
    |> put_status(:ok)
    |> json(%{data: data})
  end

  def create_offline_payment(conn, %{"broker_phone_number" => broker_phone_number, "amount" => amount, "notes" => notes} = params) do
    # Country Code is optional ,if we get it from panel we use that else +91.
    country_code = Map.get(params, "country_code", "+91")
    logged_in_user = Connection.get_logged_in_user(conn)

    with {:credential_check, credential} when not is_nil(credential) <- {:credential_check, Credential.fetch_credential(broker_phone_number, country_code, [:broker])},
         {:match_plus_check, match_package} when not is_nil(match_package) <-
           {:match_plus_check, MatchPlusPackage.fetch_active_package_for_city_with_amount(credential.broker, amount)},
         data <- Orders.create_offline_payment_entry(logged_in_user, credential, match_package, notes) do
      conn
      |> put_status(:ok)
      |> json(%{id: data.id})
    else
      {:credential_check, nil} -> {:error, "invalid broker phone number"}
      {:match_plus_check, nil} -> {:error, "no package found for #{amount} amount in the broker's operating city"}
    end
  end

  def create_offline_payment(_conn, _params), do: {:error, "broker_phone_number, amount & notes are required"}

  def payments_summary(conn, %{"payment_gateway" => "paytm", "month" => month, "year" => year} = params) when is_integer(month) and is_integer(year) do
    conn
    |> put_resp_content_type("text/csv")
    |> put_resp_header("content-disposition", "attachment; filename=\"paytm-#{month}-#{year}.csv\"")
    |> send_resp(200, params |> MatchPlusMembership.build_export_query())
  end

  def payments_summary(conn, %{"payment_gateway" => "razorpay", "month" => month, "year" => year} = params) when is_integer(month) and is_integer(year) do
    conn
    |> put_resp_content_type("text/csv")
    |> put_resp_header("content-disposition", "attachment; filename=\"razorpay-#{month}-#{year}.csv\"")
    |> send_resp(200, params |> MatchPlus.build_export_query())
  end

  def payments_summary(conn, %{"payment_gateway" => "billdesk", "month" => month, "year" => year} = params) when is_integer(month) and is_integer(year) do
    conn
    |> put_resp_content_type("text/csv")
    |> put_resp_header("content-disposition", "attachment; filename=\"billdesk-#{month}-#{year}.csv\"")
    |> send_resp(200, params |> Packages.build_export_query())
  end

  def payments_summary(conn, _params) do
    conn
    |> put_status(:bad_request)
    |> json(%{message: "Please select a payment gateway & month"})
  end
end
