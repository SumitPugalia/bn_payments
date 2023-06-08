defmodule BnApisWeb.OwnerController do
  use BnApisWeb, :controller

  alias BnApis.Accounts.EmployeeRole
  alias BnApis.Helpers.{Connection}
  alias BnApis.Accounts.Owner

  plug :access_check,
       [
         allowed_roles: [
           EmployeeRole.super().id,
           EmployeeRole.owner_supply_admin().id,
           EmployeeRole.owner_supply_operations().id
         ]
       ]
       when action in [:update_broker_flag, :get_owner]

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

  def update_broker_flag(conn, params) do
    with {:ok, data} <- Owner.update_broker_flag(params["id"], params["is_broker"]) do
      conn
      |> put_status(:ok)
      |> json(data)
    end
  end

  def get_owner(conn, params) do
    with {:ok, data} <- Owner.get_owner_by_phone(params["phone_number"], params["country_code"]) do
      conn
      |> put_status(:ok)
      |> json(data)
    end
  end
end
