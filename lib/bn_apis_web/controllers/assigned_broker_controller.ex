defmodule BnApisWeb.AssignedBrokerController do
  use BnApisWeb, :controller

  alias BnApis.Repo
  alias BnApis.Accounts.Credential
  alias BnApis.Organizations.Broker
  alias BnApis.Helpers.{Connection, AssignedBrokerHelper, ApplicationHelper}

  action_fallback BnApisWeb.FallbackController

  def dashboard(conn, _params) do
    logged_in_user = Connection.get_employee_logged_in_user(conn)

    assigned_broker_details =
      if ApplicationHelper.get_onground_apis_allowed() == "false" do
        []
      else
        assigned_broker_ids = AssignedBrokerHelper.fetch_all_active_assigned_brokers(logged_in_user.user_id)

        if length(assigned_broker_ids) > 0 do
          logged_in_user.user_id
          |> AssignedBrokerHelper.dashboard_assigned_broker_data(assigned_broker_ids)
          |> AssignedBrokerHelper.process_dashboard_data()
        else
          []
        end
      end

    conn |> put_status(:ok) |> json(%{data: assigned_broker_details})
  end

  def add_note(conn, params = %{"broker_id" => broker_id}) do
    logged_in_user = Connection.get_employee_logged_in_user(conn)
    AssignedBrokerHelper.create_note(logged_in_user.user_id, broker_id, params)
    conn |> put_status(:ok) |> json(%{message: "Successfully added"})
  end

  def snooze(conn, %{"broker_id" => broker_id, "snooze_for" => epoch_time}) do
    logged_in_user = Connection.get_employee_logged_in_user(conn)
    AssignedBrokerHelper.snooze(logged_in_user.user_id, broker_id, epoch_time)
    conn |> put_status(:ok) |> json(%{message: "Successfully snoozed"})
  end

  def mark_as_lost(conn, %{"broker_id" => broker_id, "reason" => reason}) do
    logged_in_user = Connection.get_employee_logged_in_user(conn)
    AssignedBrokerHelper.mark_lost(logged_in_user.user_id, broker_id, reason)
    conn |> put_status(:ok) |> json(%{message: "Successfully marked"})
  end

  def fetch_broker(conn, %{"broker_id" => broker_id}) do
    logged_in_user = Connection.get_employee_logged_in_user(conn)
    data = AssignedBrokerHelper.fetch_broker_data(logged_in_user.user_id, broker_id)
    conn |> put_status(:ok) |> json(%{data: data})
  end

  def search_broker(conn, %{"q" => search_text}) do
    logged_in_user = Connection.get_employee_logged_in_user(conn)
    suggestions = AssignedBrokerHelper.search_assigned_broker(logged_in_user.user_id, search_text |> String.downcase())

    conn
    |> put_status(:ok)
    |> json(%{suggestions: suggestions})
  end

  def search_organization(conn, %{"q" => search_text}) do
    logged_in_user = Connection.get_employee_logged_in_user(conn)

    suggestions = AssignedBrokerHelper.search_assigned_organization(logged_in_user.user_id, search_text |> String.downcase())

    conn
    |> put_status(:ok)
    |> json(%{suggestions: suggestions})
  end

  def create_call_log(conn, %{"broker_id" => broker_id}) do
    logged_in_user = Connection.get_employee_logged_in_user(conn)
    {:ok, call_log} = AssignedBrokerHelper.create_call_log(logged_in_user.user_id, broker_id)
    conn |> put_status(:ok) |> json(%{call_log_uuid: call_log.uuid})
  end

  def fetch_assigned_org_details(conn, %{"org_uuid" => org_uuid}) do
    logged_in_user = Connection.get_employee_logged_in_user(conn)
    org_details = AssignedBrokerHelper.fetch_assigned_org_details(logged_in_user.user_id, org_uuid)
    conn |> put_status(:ok) |> json(org_details)
  end

  def fetch_or_create_sendbird_channel_for_broker(conn, %{"broker_uuid" => broker_uuid}) do
    logged_in_user = Connection.get_employee_logged_in_user(conn)

    with {:ok, broker} <- fetch_broker(broker_uuid),
         {:ok, channel_details} <-
           AssignedBrokerHelper.fetch_or_create_sendbird_channel(broker.id, broker_uuid, broker.name, logged_in_user.user_id, logged_in_user.uuid, logged_in_user.vertical_id) do
      conn
      |> put_status(:ok)
      |> json(channel_details)
    end
  end

  def fetch_broker(broker_uuid) do
    with %Credential{broker_id: broker_id, active: true} = _cred <- Repo.get_by(Credential, uuid: broker_uuid),
         %Broker{} = broker <- Repo.get_by(Broker, id: broker_id) do
      {:ok, broker}
    else
      nil -> {:error, :not_found}
    end
  end
end
