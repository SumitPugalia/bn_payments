defmodule BnApisWeb.V1.AssignedBrokerController do
  use BnApisWeb, :controller

  alias BnApis.Helpers.{Connection, AssignedBrokerHelper, ApplicationHelper}

  def list_assigned_brokers(conn, _params) do
    logged_in_user = Connection.get_employee_logged_in_user(conn)

    assigned_broker_details =
      if ApplicationHelper.get_onground_apis_allowed() == "false" do
        []
      else
        assigned_broker_ids = AssignedBrokerHelper.fetch_all_active_assigned_brokers(logged_in_user.user_id)

        if length(assigned_broker_ids) > 0 do
          logged_in_user.user_id
          |> AssignedBrokerHelper.dashboard_assigned_broker_data(assigned_broker_ids)
          |> AssignedBrokerHelper.filter_and_sort_by_broker()
        else
          []
        end
      end

    conn |> put_status(:ok) |> json(%{data: assigned_broker_details})
  end
end
