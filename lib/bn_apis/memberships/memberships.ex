defmodule BnApis.Memberships do
  @moduledoc """
  The Memberships context.
  """

  import Ecto.Query, warn: false
  alias BnApis.Repo

  alias BnApis.Accounts.Credential
  alias BnApis.Memberships
  alias BnApis.Memberships.Membership
  alias BnApis.Memberships.MembershipOrder
  alias BnApis.Memberships.MatchPlusMembership
  alias BnApis.Orders.Order
  alias BnApis.Orders.OrderPayment
  alias BnApis.Orders.MatchPlusPackage
  alias BnApis.Helpers.ApplicationHelper
  alias BnApis.Helpers.PaytmMembershipHelper
  alias BnApis.Helpers.Time

  @update_status_retry_interval_in_seconds 5
  @update_registration_status_number_of_retries 5

  def update_status_retry_interval_in_seconds do
    @update_status_retry_interval_in_seconds
  end

  # Apis for App
  def create_membership(params, session_data) do
    broker_id = session_data |> get_in(["profile", "broker_id"])
    broker_city_id = session_data |> get_in(["profile", "operating_city"])

    match_plus_package =
      if not is_nil(params["package_uuid"]),
        do: MatchPlusPackage.fetch_active_autopay_package_from_uuid_and_city(params["package_uuid"], broker_city_id),
        else: nil

    cond do
      not is_nil(params["package_uuid"]) and is_nil(match_plus_package) ->
        {:error, "No such package found"}

      true ->
        match_plus_package_id = if is_nil(match_plus_package), do: nil, else: match_plus_package.id

        match_plus_membership =
          MatchPlusMembership.find_or_create!(broker_id)
          |> Repo.preload([:latest_membership])

        latest_membership = match_plus_membership.latest_membership

        cond do
          check_eligility_for_membership_creation(match_plus_membership) ->
            Repo.transaction(fn ->
              try do
                subscription_response = create_paytm_membership(broker_id, broker_city_id, match_plus_package, latest_membership)

                paytm_txn_token = subscription_response["body"]["txnToken"]
                paytm_subscription_id = subscription_response["body"]["subscriptionId"]
                response = get_paytm_membership(paytm_subscription_id)
                membership_params = get_params_for_membership(response, broker_id, match_plus_membership.id)
                membership = Membership.create_membership!(paytm_txn_token, membership_params, match_plus_package_id)
                MatchPlusMembership.update_latest_membership!(match_plus_membership, membership.id)

                %{
                  id: membership.id,
                  status: membership.status,
                  bn_order_id: membership.bn_order_id,
                  paytm_txn_token: membership.paytm_txn_token,
                  amount: membership.subscription_amount,
                  merchant_id: ApplicationHelper.get_paytm_merchant_id(),
                  paytm_subscription_id: membership.paytm_subscription_id
                }
              rescue
                _ ->
                  Repo.rollback("Unable to store data")
              end
            end)

          true ->
            {:error, "There is an active membership running already!"}
        end
    end
  end

  def update_membership(params, session_data) do
    broker_id = session_data |> get_in(["profile", "broker_id"])

    case params do
      %{
        "id" => id
      } ->
        membership = Membership.get_membership(id)

        cond do
          is_nil(membership) ->
            {:error, "No such membership found"}

          membership.broker_id != broker_id ->
            {:error, "You are not authorised to update this membership"}

          true ->
            response = get_paytm_membership(membership.paytm_subscription_id)
            membership_params = get_params_for_membership(response, broker_id, membership.match_plus_membership_id)

            Repo.transaction(fn ->
              try do
                membership = Membership.update_membership!(membership, membership_params)

                %{
                  id: membership.id,
                  status: membership.status,
                  paytm_subscription_id: membership.paytm_subscription_id
                }
              rescue
                _ ->
                  Repo.rollback("Unable to store data")
              end
            end)
        end

      _ ->
        {:error, "Invalid params"}
    end
  end

  def handle_subscription_webhook(paytm_subscription_id, _params) do
    Repo.transaction(fn ->
      try do
        membership = Repo.get_by(Membership, paytm_subscription_id: paytm_subscription_id)

        if not is_nil(membership) do
          # Membership.update_status!(membership, params[:status], params)
          response = get_paytm_membership(membership.paytm_subscription_id)

          membership_params = get_params_for_membership(response, membership.broker_id, membership.match_plus_membership_id)

          Membership.update_membership!(membership, membership_params)
        end
      rescue
        _ ->
          Repo.rollback("Unable to process paytm subscription webhook")
      end
    end)
  end

  def mark_membership_as_registered(params, session_data) do
    broker_id = session_data |> get_in(["profile", "broker_id"])

    case params do
      %{
        "id" => id
      } ->
        membership = Membership.get_membership(id)

        cond do
          is_nil(membership) ->
            {:error, "No such membership found"}

          membership.broker_id != broker_id ->
            {:error, "You are not authorised to update this membership"}

          true ->
            response = get_paytm_membership(membership.paytm_subscription_id)

            membership_params =
              get_params_for_membership(response, broker_id, membership.match_plus_membership_id)
              |> Map.put(:is_client_side_registration_successful, true)

            Repo.transaction(fn ->
              try do
                membership = Membership.update_membership!(membership, membership_params)

                if membership.status != Membership.active_status() do
                  Exq.enqueue_in(
                    Exq,
                    "update_membership_status",
                    Memberships.update_status_retry_interval_in_seconds(),
                    BnApis.Memberships.UpdateMembershipStatusWorker,
                    [id, @update_registration_status_number_of_retries]
                  )
                end

                %{
                  id: membership.id,
                  status: membership.status,
                  paytm_subscription_id: membership.paytm_subscription_id
                }
              rescue
                _ ->
                  Repo.rollback("Unable to store data")
              end
            end)
        end

      _ ->
        {:error, "Invalid params"}
    end
  end

  def cancel_membership(params, session_data) do
    broker_id = session_data |> get_in(["profile", "broker_id"])

    case params do
      %{
        "id" => id
      } ->
        membership = Membership.get_membership(id)

        cond do
          is_nil(membership) ->
            {:error, "No such membership found"}

          membership.broker_id != broker_id ->
            {:error, "You are not authorised to cancel this membership"}

          true ->
            {status_code, _response} = cancel_paytm_membership(membership.paytm_subscription_id)

            if status_code != 200 do
              {:error, "Subscription could not be cancelled, please try later!"}
            else
              response = get_paytm_membership(membership.paytm_subscription_id)
              membership_params = get_params_for_membership(response, broker_id, membership.match_plus_membership_id)

              Repo.transaction(fn ->
                try do
                  membership = Membership.update_membership!(membership, membership_params)

                  %{
                    id: membership.id,
                    status: membership.status,
                    paytm_subscription_id: membership.paytm_subscription_id
                  }
                rescue
                  _ ->
                    Repo.rollback("Unable to store data")
                end
              end)
            end
        end

      _ ->
        {:error, "Invalid params"}
    end
  end

  def update_gst(params, session_data) do
    broker_id = session_data |> get_in(["profile", "broker_id"])

    case params do
      %{
        "membership_order_id" => membership_order_id
      } ->
        membership_order =
          Repo.get_by(MembershipOrder, id: membership_order_id)
          |> Repo.preload([:membership])

        cond do
          is_nil(membership_order) ->
            {:error, "No such membership order found"}

          membership_order.membership.broker_id != broker_id ->
            {:error, "You are not authorised to access this membership order"}

          membership_order.order_status != "SUCCESS" ->
            {:error, "Invoice can only be generated for successful membership orders"}

          !membership_order_belongs_to_current_month(membership_order) ->
            {:error, "GST information can only be updated for current month membership orders"}

          true ->
            Repo.transaction(fn ->
              try do
                membership_order = MembershipOrder.update_gst!(membership_order, params)

                %{
                  id: membership_order.id,
                  invoice_url: membership_order.invoice_url,
                  message: "GST details have been captured successfully. You will be notified once Invoice is ready!"
                }
              rescue
                _ ->
                  Repo.rollback("Unable to store data")
              end
            end)
        end

      _ ->
        {:error, "Invalid params"}
    end
  end

  def fetch_membership_details(params, session_data) do
    broker_id = session_data |> get_in(["profile", "broker_id"])

    case params do
      %{
        "id" => id
      } ->
        membership = Membership.get_membership(id)

        cond do
          is_nil(membership) ->
            {:error, "No such membership found"}

          membership.broker_id != broker_id ->
            {:error, "You are not authorised to update this membership"}

          true ->
            response = get_paytm_membership(membership.paytm_subscription_id)
            membership_params = get_params_for_membership(response, broker_id, membership.match_plus_membership_id)

            Repo.transaction(fn ->
              try do
                membership = Membership.update_membership!(membership, membership_params)

                match_plus_data =
                  Repo.get_by(MatchPlusMembership, broker_id: broker_id)
                  |> MatchPlusMembership.get_data()

                %{
                  id: membership.id,
                  status: membership.status,
                  paytm_subscription_id: membership.paytm_subscription_id,
                  match_plus_data: match_plus_data
                }
              rescue
                _ ->
                  Repo.rollback("Unable to store data")
              end
            end)
        end

      _ ->
        {:error, "Invalid params"}
    end
  end

  def fetch_paytm_subscription_details(params, session_data) do
    broker_id = session_data |> get_in(["profile", "broker_id"])

    case params do
      %{
        "id" => id
      } ->
        membership = Membership.get_membership(id)

        cond do
          is_nil(membership) ->
            {:error, "No such membership found"}

          membership.broker_id != broker_id ->
            {:error, "You are not authorised to fetch this membership"}

          true ->
            response = get_paytm_membership(membership.paytm_subscription_id)
            {:ok, response}
        end

      _ ->
        {:error, "Invalid params"}
    end
  end

  def fetch_transaction_history(params, session_data) do
    {mo_data, mo_has_more, mo_total_count} = fetch_membership_orders_txn_history(params, session_data)
    {o_data, o_has_more, o_total_count} = fetch_orders_txn_history(params, session_data)

    data =
      (mo_data ++ o_data)
      |> Enum.sort_by(fn txn -> txn[:order_creation_date] end, &>=/2)

    total_count = mo_total_count + o_total_count
    has_more = mo_has_more || o_has_more

    data = %{
      "data" => data,
      "has_more" => has_more,
      "total_count" => total_count
    }

    {:ok, data}
  end

  def fetch_membership_orders_txn_history(params, session_data) do
    page_no = (params["p"] || "1") |> String.to_integer()
    size = (params["size"] || "5") |> String.to_integer()
    broker_id = session_data |> get_in(["profile", "broker_id"])
    {current_time, beginning_of_month, end_of_month_minus_one_day, end_of_month_five_pm, end_of_month} = Time.get_current_month_limits_in_unix()
    current_time_less_than_end_of_month_minus_one_day = current_time < end_of_month_minus_one_day
    current_time_less_than_end_of_month_five_pm = current_time < end_of_month_five_pm

    query =
      MembershipOrder
      |> join(:inner, [mo], m in Membership, on: mo.membership_id == m.id)
      |> join(:left, [mo, m], mpp in MatchPlusPackage, on: m.match_plus_package_id == mpp.id)
      |> where([mo, m], m.broker_id == ^broker_id)
      |> where([mo, m], mo.order_status == "SUCCESS" or not is_nil(mo.resp_code))
      |> order_by([mo, m], desc: mo.order_creation_date)
      |> select([mo, m, mpp], %{
        paytm_subscription_id: m.paytm_subscription_id,
        paytm_order_id: mo.order_id,
        membership_id: mo.membership_id,
        membership_order_id: mo.id,
        order_status: mo.order_status,
        order_invoice_url: mo.invoice_url,
        is_gst_invoice: mo.is_gst_invoice,
        capture_gst:
          fragment(
            """
              CASE
                WHEN ? is FALSE AND ? > ? and ? < ? and ? THEN TRUE
                WHEN ? is FALSE AND ? > ? and ? < ? and ? THEN TRUE
                ELSE FALSE
              END
            """,
            mo.is_gst_invoice,
            mo.order_creation_date,
            ^beginning_of_month,
            mo.order_creation_date,
            ^end_of_month_minus_one_day,
            ^current_time_less_than_end_of_month_minus_one_day,
            mo.is_gst_invoice,
            mo.order_creation_date,
            ^end_of_month_minus_one_day,
            mo.order_creation_date,
            ^end_of_month,
            ^current_time_less_than_end_of_month_five_pm
          ),
        order_status_title:
          fragment(
            """
              CASE WHEN ? = 'SUCCESS' THEN 'Successful' WHEN ? = 'FAIL' THEN 'Failed' ELSE 'In Progress' END
            """,
            mo.order_status,
            mo.order_status
          ),
        order_creation_date: mo.order_creation_date,
        order_amount: mo.order_amount,
        response_message: mo.response_message,
        resp_code: mo.resp_code,
        payment_mode: "paytm",
        auto_renew: true
      })

    total_count = query |> Repo.aggregate(:count, :id)

    response = query |> limit(^size) |> offset(^((page_no - 1) * size)) |> Repo.all()

    has_more = Enum.count(response) >= size
    {response, has_more, total_count}
  end

  def fetch_orders_txn_history(params, session_data) do
    page_no = (params["p"] || "1") |> String.to_integer()
    size = (params["size"] || "5") |> String.to_integer()
    broker_id = session_data |> get_in(["profile", "broker_id"])
    {current_time, beginning_of_month, end_of_month_minus_one_day, end_of_month_five_pm, end_of_month} = Time.get_current_month_limits_in_unix()
    current_time_less_than_end_of_month_minus_one_day = current_time < end_of_month_minus_one_day
    current_time_less_than_end_of_month_five_pm = current_time < end_of_month_five_pm

    query =
      Order
      |> join(:inner, [o], op in OrderPayment, on: o.id == op.order_id)
      |> where([o, op], o.broker_id == ^broker_id)
      |> where([o, op], o.status == ^Order.paid_status())
      |> where([o, op], op.razorpay_payment_status == ^OrderPayment.captured_status())
      |> order_by([o, op], desc: op.created_at)
      |> select([o, op], %{
        razorpay_order_id: o.razorpay_order_id,
        order_id: o.id,
        razorpay_payment_id: op.razorpay_payment_id,
        order_status:
          fragment(
            """
              CASE WHEN ? = 'paid' THEN 'SUCCESS' ELSE 'PENDING' END
            """,
            o.status
          ),
        order_invoice_url: o.invoice_url,
        is_gst_invoice: o.is_gst_invoice,
        capture_gst:
          fragment(
            """
              CASE
                WHEN ? is FALSE AND ? > ? and ? < ? and ? THEN TRUE
                WHEN ? is FALSE AND ? > ? and ? < ? and ? THEN TRUE
                ELSE FALSE
              END
            """,
            o.is_gst_invoice,
            op.created_at,
            ^beginning_of_month,
            op.created_at,
            ^end_of_month_minus_one_day,
            ^current_time_less_than_end_of_month_minus_one_day,
            o.is_gst_invoice,
            op.created_at,
            ^end_of_month_minus_one_day,
            op.created_at,
            ^end_of_month,
            ^current_time_less_than_end_of_month_five_pm
          ),
        order_status_title: "Successful",
        order_creation_date: op.created_at,
        order_amount:
          fragment(
            """
              CAST((? / 100) as VARCHAR)
            """,
            op.amount
          ),
        response_message: nil,
        resp_code: nil,
        payment_mode: "razorpay",
        auto_renew: false
      })

    total_count = query |> Repo.aggregate(:count, :id)

    response = query |> limit(^size) |> offset(^((page_no - 1) * size)) |> Repo.all()

    has_more = Enum.count(response) >= size
    {response, has_more, total_count}
  end

  # Private methods
  defp check_eligility_for_membership_creation(match_plus_membership) do
    match_plus_membership =
      match_plus_membership
      |> Repo.preload([:latest_membership, :memberships])

    cond do
      Enum.member?(
        Enum.map(match_plus_membership.memberships, fn s -> s.status end),
        Membership.active_status()
      ) ->
        false

      # (!is_nil(match_plus_membership.latest_membership) and Enum.member?([Membership.created_status, Membership.authenticated_status], match_plus_membership.latest_membership.status)) ->
      #   false

      # match_plus_membership.status_id == MatchPlusMembership.active_status_id ->
      #   false

      true ->
        true
    end
  end

  defp membership_order_belongs_to_current_month(membership_order) do
    {current_time, beginning_of_month, end_of_month_minus_one_day, end_of_month_five_pm, end_of_month} = Time.get_current_month_limits_in_unix()

    cond do
      membership_order.order_creation_date > beginning_of_month and membership_order.order_creation_date < end_of_month_minus_one_day and current_time < end_of_month_minus_one_day ->
        true

      membership_order.order_creation_date > end_of_month_minus_one_day and membership_order.order_creation_date < end_of_month and current_time < end_of_month_five_pm ->
        true

      true ->
        false
    end
  end

  defp create_paytm_membership(broker_id, broker_city_id, match_plus_package, latest_membership) do
    current_timestamp = DateTime.utc_now() |> DateTime.to_unix()

    subscription_amount =
      if !is_nil(match_plus_package),
        do: match_plus_package.amount_in_rupees,
        else: MatchPlusPackage.get_default_autopay_amount_by_city(broker_city_id)

    {start_date, start_transaction_amount, renewal_amount} =
      if !is_nil(latest_membership) and
           latest_membership.last_order_status == Membership.order_success() and
           current_timestamp <= latest_membership.current_end do
        {:ok, datetime} = DateTime.from_unix(latest_membership.current_end)
        start_date = datetime |> Timex.shift(days: 1)
        {start_date, Membership.default_txn_amount(), subscription_amount}
      else
        start_date = Timex.now()
        {start_date, subscription_amount, subscription_amount}
      end

    date_format = "{YYYY}-{0M}-{0D}"

    formatted_start_date =
      start_date
      |> Timex.Timezone.convert("Asia/Kolkata")
      |> Timex.format!(date_format)

    formatted_expiry_date =
      formatted_start_date
      |> Timex.parse!(date_format)
      |> Timex.to_datetime()
      |> Timex.shift(days: 366)
      |> Timex.format!(date_format)

    order_id = "BN_ORDERID_#{SecureRandom.urlsafe_base64(8)}"
    cust_id = "CUST_#{broker_id}"

    PaytmMembershipHelper.create_subscription(
      cust_id,
      order_id,
      formatted_start_date,
      formatted_expiry_date,
      start_transaction_amount,
      renewal_amount
    )
  end

  def get_paytm_membership(paytm_subscription_id) do
    PaytmMembershipHelper.get_subscription_details(paytm_subscription_id)
  end

  def cancel_paytm_membership(paytm_subscription_id) do
    PaytmMembershipHelper.cancel_subscription(paytm_subscription_id)
  end

  def get_params_for_membership(response, broker_id, match_plus_membership_id) do
    credential = Credential.get_credential_from_broker_id(broker_id)

    credential =
      if not is_nil(credential),
        do: credential,
        else: Credential.get_any_credential_from_broker_id(broker_id)

    response = response["body"]

    created_at =
      response["createdDate"]
      |> NaiveDateTime.from_iso8601!()
      |> Timex.to_datetime("Asia/Kolkata")
      |> Timex.Timezone.convert("Etc/UTC")
      |> Timex.to_datetime()
      |> DateTime.to_unix()

    last_order_creation_date =
      response["lastOrderCreationDate"]
      |> NaiveDateTime.from_iso8601!()
      |> Timex.to_datetime("Asia/Kolkata")
      |> Timex.Timezone.convert("Etc/UTC")
      |> Timex.to_datetime()
      |> DateTime.to_unix()

    %{
      bn_order_id: response["orderId"],
      paytm_subscription_id: response["subsId"],
      created_at: created_at,
      bn_customer_id: response["custId"],
      status: response["status"],
      short_url: response["short_url"],
      last_order_id: response["lastOrderId"],
      last_order_status: response["lastOrderStatus"],
      last_order_creation_date: last_order_creation_date,
      subscription_amount: response["maxAmount"],
      last_order_amount: response["lastOrderAmount"],
      response_message: response["respMsg"],
      resp_code: response["respCode"],
      payment_method: response["subsPaymentInstDetails"]["paymentMode"],
      broker_phone_number: credential.phone_number,
      broker_id: broker_id,
      match_plus_membership_id: match_plus_membership_id,
      paytm_data: response
    }
  end
end
