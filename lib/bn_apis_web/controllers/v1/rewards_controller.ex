defmodule BnApisWeb.V1.RewardsController do
  use BnApisWeb, :controller

  alias BnApis.Rewards
  alias BnApis.Rewards.{RewardsLead, DisabledRewardsReasons}
  alias BnApis.Helpers.Connection
  alias BnApis.Accounts.{EmployeeRole, EmployeeVertical}
  alias BnApisWeb.Plugs.DeveloperPocSessionPlug
  alias BnApis.AssignedBrokers

  action_fallback(BnApisWeb.FallbackController)

  plug :access_check,
       [
         allowed_roles: [
           EmployeeRole.super().id,
           EmployeeRole.admin().id,
           EmployeeRole.broker_admin().id,
           EmployeeRole.member().id,
           EmployeeRole.investor().id
         ],
         allowed_verticals: [EmployeeVertical.get_vertical_by_identifier("PROJECT")["id"], EmployeeVertical.get_vertical_by_identifier("BN")["id"]]
       ]
       when action in [:get_rewards_leads, :get_rewards_leads_aggregate]

  plug :access_check,
       [
         allowed_roles: [EmployeeRole.super().id, EmployeeRole.member().id],
         allowed_verticals: [EmployeeVertical.get_vertical_by_identifier("PROJECT")["id"], EmployeeVertical.get_vertical_by_identifier("BN")["id"]]
       ]
       when action in [
              :approve_rewards_request_by_manager,
              :reject_rewards_request_by_manager,
              :close_rewards_request_by_manager
            ]

  defp access_check(conn, options) do
    logged_in_user = Connection.get_employee_logged_in_user(conn)

    if logged_in_user.employee_role_id in options[:allowed_roles] and logged_in_user.vertical_id in options[:allowed_verticals] do
      conn
    else
      conn
      |> send_resp(403, "Sorry, You are not authorized to take this action!")
      |> halt()
    end
  end

  # Api for Broker App
  def create_lead(conn, params) do
    with {:ok, data} <- Rewards.create_lead(params, conn.assigns[:user]) do
      conn
      |> put_status(:ok)
      |> json(data)
    end
  end

  def update_lead(conn, params) do
    with {:ok, data} <- Rewards.update_lead(params, conn.assigns[:user]) do
      conn
      |> put_status(:ok)
      |> json(data)
    end
  end

  def delete_lead(conn, params) do
    with {:ok, data} <- Rewards.delete_lead(params, conn.assigns[:user]) do
      conn
      |> put_status(:ok)
      |> json(data)
    end
  end

  def broker_history(conn, params) do
    with {:ok, data} <- Rewards.get_broker_history(params, conn.assigns[:user]) do
      conn
      |> put_status(:ok)
      |> json(data)
    end
  end

  def get_leads(conn, params) do
    with {:ok, data} <- Rewards.get_leads(params, conn.assigns[:user]) do
      conn
      |> put_status(:ok)
      |> json(data)
    end
  end

  def get_draft_leads(conn, params) do
    with {:ok, data} <- Rewards.get_draft_leads(params, conn.assigns[:user]) do
      conn
      |> put_status(:ok)
      |> json(data)
    end
  end

  # Api for developer App
  def get_pending_rewards_request(conn, params) do
    with {:ok, data} <-
           Rewards.get_pending_rewards_request(params, conn.assigns[:user]) do
      conn
      |> put_status(:ok)
      |> json(data)
    end
  end

  def get_rejected_rewards_request(conn, params) do
    with {:ok, data} <-
           Rewards.get_rejected_rewards_request(params, conn.assigns[:user]) do
      conn
      |> put_status(:ok)
      |> json(data)
    end
  end

  def get_approved_rewards_request(conn, params) do
    with {:ok, data} <-
           Rewards.get_approved_rewards_request(params, conn.assigns[:user]) do
      conn
      |> put_status(:ok)
      |> json(data)
    end
  end

  def search_leads(conn, params) do
    with {:ok, data} <-
           Rewards.search_leads(params, conn.assigns[:user]) do
      conn
      |> put_status(:ok)
      |> json(data)
    end
  end

  def approve_rewards_request(conn, params) do
    device_info = DeveloperPocSessionPlug.get_app_device_info(conn)

    with {:ok, data} <-
           Rewards.approve_rewards_request_by_developer_poc(
             params,
             conn.assigns[:user],
             false,
             device_info
           ) do
      conn
      |> put_status(:ok)
      |> json(data)
    end
  end

  def reject_rewards_request(conn, params) do
    device_info = DeveloperPocSessionPlug.get_app_device_info(conn)

    with {:ok, data} <-
           Rewards.reject_rewards_request_by_developer_poc(
             params,
             conn.assigns[:user],
             device_info
           ) do
      conn
      |> put_status(:ok)
      |> json(data)
    end
  end

  def razorpay_webhook(conn, params) do
    with {:ok, _data} <- Rewards.handle_razorpay_webhook(params) do
      conn |> put_status(:ok) |> json(%{})
    end
  end

  def get_rewards_leads_aggregate(conn, params) do
    logged_in_user = Connection.get_employee_logged_in_user(conn)

    params =
      if not Enum.member?(
           [EmployeeRole.broker_admin().id, EmployeeRole.super().id, EmployeeRole.admin().id, EmployeeRole.investor().id],
           logged_in_user.employee_role_id
         ) do
        Map.put(
          params,
          "assigned_broker_ids",
          AssignedBrokers.fetch_all_active_assigned_brokers(logged_in_user.user_id)
        )
      else
        params
      end

    with status_wise_response <- RewardsLead.get_rewards_leads_aggregate(params) do
      conn
      |> put_status(:ok)
      |> json(status_wise_response)
    end
  end

  def get_rewards_leads(conn, params) do
    logged_in_user = Connection.get_employee_logged_in_user(conn)

    params =
      if not Enum.member?(
           [EmployeeRole.broker_admin().id, EmployeeRole.super().id, EmployeeRole.admin().id, EmployeeRole.investor().id],
           logged_in_user.employee_role_id
         ) do
        Map.put(
          params,
          "assigned_broker_ids",
          AssignedBrokers.fetch_all_active_assigned_brokers(logged_in_user.user_id)
        )
      else
        params
      end

    with {total_count, has_more_leads, leads, _} <- RewardsLead.get_rewards_leads(params) do
      conn
      |> put_status(:ok)
      |> json(%{
        leads: leads,
        total_count: total_count,
        has_more_leads: has_more_leads
      })
    end
  end

  def approve_rewards_request_by_manager(conn, params) do
    logged_in_user = Connection.get_employee_logged_in_user(conn)

    with {:ok, message} <- Rewards.action_on_rewards_request_by_manager(logged_in_user, params, "pending") do
      conn
      |> put_status(:ok)
      |> json(%{"message" => message})
    else
      {:error, error_message} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{message: error_message})
    end
  end

  def reject_rewards_request_by_manager(conn, params) do
    logged_in_user = Connection.get_employee_logged_in_user(conn)

    with {:ok, message} <- Rewards.action_on_rewards_request_by_manager(logged_in_user, params, "rejected_by_manager") do
      conn
      |> put_status(:ok)
      |> json(%{"message" => message})
    else
      {:error, error_message} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{message: error_message})
    end
  end

  def close_rewards_request_by_manager(conn, params) do
    logged_in_user = Connection.get_employee_logged_in_user(conn)

    with {:ok, message} <- Rewards.action_on_rewards_request_by_manager(logged_in_user, params, "claim_closed") do
      conn
      |> put_status(:ok)
      |> json(%{"message" => message})
    else
      {:error, error_message} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{message: error_message})
    end
  end

  # API to share list of disabled_rewards_reasons with the FE
  def get_disabled_rewards_reasons(conn, _params) do
    reasons = DisabledRewardsReasons.get_all_reasons()

    conn
    |> put_status(:ok)
    |> json(%{reasons: reasons})
  end
end
