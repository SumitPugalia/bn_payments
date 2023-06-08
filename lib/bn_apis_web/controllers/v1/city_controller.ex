defmodule BnApisWeb.V1.CityController do
  use BnApisWeb, :controller

  alias BnApis.Accounts.EmployeeRole
  alias BnApis.Helpers.Connection
  alias BnApis.Places.City

  action_fallback BnApisWeb.FallbackController

  plug :access_check, [allowed_roles: [EmployeeRole.super().id]] when action in [:update_city]

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

  def list_cities_with_owner_subscription(conn, _params) do
    response = City.list_cities_with_owner_subscription()

    conn
    |> put_status(:ok)
    |> json(response)
  end

  def get_cities_list(conn, _params) do
    response = City.get_cities_list()

    conn
    |> put_status(:ok)
    |> json(response)
  end

  def update_city(conn, params) do
    with {:ok, data} <- City.update_city(params) do
      conn
      |> put_status(:ok)
      |> json(data)
    end
  end
end
