defmodule BnApisWeb.V1.ZoneController do
  use BnApisWeb, :controller
  alias BnApis.Places.Zone
  alias BnApis.Accounts.EmployeeRole
  alias BnApis.Helpers.Connection

  plug :access_check,
       [allowed_roles: [EmployeeRole.super().id, EmployeeRole.admin().id]] when action in [:create, :update]

  def index(conn, params) do
    zones = Zone.all_zones(params)
    render(conn, "index.json", zones: zones)
  end

  def show(conn, %{"uuid" => uuid}) do
    with {:ok, zone} <- Zone.fetch_from_uuid(uuid) do
      render(conn, "show.json", zone: zone)
    else
      {:error, :not_found} ->
        conn
        |> put_status(:not_found)
        |> json(%{message: "Zone does not exist."})
    end
  end

  def create(conn, %{"zone_data" => zone_data_params}) do
    case Zone.create(zone_data_params) do
      {:ok, zone} ->
        render(conn, "show.json", zone: zone)

      {:error, errors} ->
        conn |> put_status(:unprocessable_entity) |> json(%{message: inspect(errors)})
    end
  end

  def update(conn, %{"zone_data" => zone_data}) do
    {:ok, zone} = Zone.update_zone(zone_data)
    render(conn, "show.json", zone: zone)
  end

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
end
