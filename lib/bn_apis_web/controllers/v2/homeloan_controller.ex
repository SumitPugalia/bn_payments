defmodule BnApisWeb.V2.HomeloanController do
  use BnApisWeb, :controller

  alias BnApis.Homeloans
  alias BnApis.Accounts.EmployeeRole
  alias BnApis.Helpers.Connection
  alias BnApis.Helpers.Utils

  action_fallback(BnApisWeb.FallbackController)

  plug :access_check,
       [
         allowed_roles: [
           EmployeeRole.super().id,
           EmployeeRole.hl_agent().id,
           EmployeeRole.hl_super().id,
           EmployeeRole.hl_executive().id,
           EmployeeRole.dsa_agent().id,
           EmployeeRole.dsa_admin().id,
           EmployeeRole.dsa_super().id
         ]
       ]
       when action in [:aggregate_leads, :lead_list_by_filter, :leads_by_phone_number]

  defp access_check(conn, options) do
    logged_in_user = Connection.get_employee_logged_in_user(conn)

    if logged_in_user.employee_role_id in options[:allowed_roles] do
      conn
    else
      conn
      |> send_resp(401, "Sorry, You are not authorized to take this action!")
      |> halt()
    end
  end

  # Api for Broker App
  def get_leads(conn, params) do
    {:ok, page_no, page_size, q, is_employee} = get_lead_list_params(params)

    with {:ok, data} <- Homeloans.lead_list_for_dsa(conn.assigns[:user], page_no, page_size, q, is_employee, params) do
      conn
      |> put_status(:ok)
      |> json(data)
    end
  end

  defp get_lead_list_params(params) do
    page_no = Map.get(params, "p", "1") |> String.to_integer()
    page_size = Map.get(params, "size", "10") |> String.to_integer()
    q = Map.get(params, "q")
    is_employee = Utils.parse_boolean_param(Map.get(params, "is_employee", "false"))
    {:ok, page_no, page_size, q, is_employee}
  end

  def update_lead_status(conn, params) do
    with {:ok, _} <- Homeloans.update_status(params, conn.assigns[:user], "V2") do
      conn
      |> put_status(:ok)
      |> json(%{})
    end
  end

  def get_lead_data(conn, params = %{"lead_id" => _lead_id}) do
    logged_in_user = Connection.get_logged_in_user(conn)

    with {:ok, data} <- Homeloans.get_lead_data(params, logged_in_user.broker_id, "V2") do
      conn
      |> put_status(:ok)
      |> json(data)
    end
  end

  def aggregate_leads(conn, params) do
    with {:ok, data} <- Homeloans.aggregate_leads(params, conn.assigns[:user], "V2") do
      conn
      |> put_status(:ok)
      |> json(data)
    end
  end

  def lead_list_by_filter(conn, params) do
    with {:ok, data} <- Homeloans.list_leads_by_status(params, conn.assigns[:user], "V2") do
      conn
      |> put_status(:ok)
      |> json(data)
    end
  end

  def leads_by_phone_number(conn, params) do
    with {:ok, data} <- Homeloans.list_leads_by_phone(params, conn.assigns[:user], "V2") do
      conn
      |> put_status(:ok)
      |> json(data)
    end
  end
end
