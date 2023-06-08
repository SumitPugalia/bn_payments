defmodule BnApisWeb.PolygonController do
  use BnApisWeb, :controller
  alias BnApis.Places.Polygon
  alias BnApis.Accounts.EmployeeRole
  alias BnApisWeb.Helpers.PolygonHelper
  alias BnApis.Helpers.{Connection, Utils}

  plug :access_check, [allowed_roles: [EmployeeRole.super().id]] when action in [:create, :update]

  def index(conn, _params) do
    polygons = Polygon.all_polygons()
    render(conn, "index.json", polygons: polygons)
  end

  def show(conn, %{"uuid" => uuid}) do
    polygon = Polygon.fetch_from_uuid(uuid)
    render(conn, "show.json", polygon: polygon)
  end

  def get_polygons_from_zone_id(conn, %{"zone_id" => zone_id}) do
    case Polygon.fetch_from_zone_id(zone_id) do
      {:ok, polygons} ->
        render(conn, "index.json", polygons: polygons)

      {:error, errors} ->
        conn |> put_status(:unprocessable_entity) |> json(%{message: inspect(errors)})
    end
  end

  def get_polygons_from_city_id(conn, %{"city_id" => city_id}) do
    case Polygon.fetch_from_city_id(city_id) do
      {:ok, polygons} ->
        render(conn, "index.json", polygons: polygons)

      {:error, errors} ->
        conn |> put_status(:unprocessable_entity) |> json(%{message: inspect(errors)})
    end
  end

  def add_zone_to_polygon_using_id(conn, %{"zone_id" => zone_id, "polygon_id" => polygon_id}) do
    case Polygon.add_zone_to_polygon_id(%{"zone_id" => zone_id, "polygon_id" => polygon_id}) do
      {:ok, polygon} ->
        render(conn, "show.json", polygon: polygon)

      {:error, errors} ->
        conn |> put_status(:unprocessable_entity) |> json(%{message: inspect(errors)})
    end
  end

  def create(conn, %{"polygon_data" => polygon_data_params}) do
    case Polygon.create(polygon_data_params) do
      {:ok, polygon} ->
        render(conn, "show.json", polygon: polygon)

      {:error, errors} ->
        conn |> put_status(:unprocessable_entity) |> json(%{message: inspect(errors)})
    end
  end

  def update(conn, %{"uuid" => uuid, "polygon_data" => polygon_data_params}) do
    polygon = Polygon.fetch_from_uuid(uuid)

    with {:ok, %Polygon{} = polygon} <- Polygon.update(polygon, polygon_data_params) do
      render(conn, "show.json", polygon: polygon)
    end
  end

  def search(conn, params) do
    search_text = params["q"]
    city_id = Utils.parse_to_integer(params["city_id"])
    response = Polygon.search_polygons(search_text, city_id)

    conn
    |> put_status(:ok)
    |> json(%{data: response})
  end

  def search_for_broker(conn, params) do
    logged_in_user = Connection.get_logged_in_user(conn)
    operating_city = logged_in_user.operating_city
    response = Polygon.aggregated_search_results(params, operating_city)

    conn
    |> put_status(:ok)
    |> json(%{data: response})
  end

  def search_for_admin(conn, params) do
    response = Polygon.aggregated_search_results(params)

    conn
    |> put_status(:ok)
    |> json(%{data: response})
  end

  def get_cities_list(conn, _params) do
    cities_list = PolygonHelper.fetch_cities_data()
    conn |> put_status(:ok) |> json(cities_list)
  end

  def predict_polygon(conn, %{"type" => type, "q" => query}) do
    predictions = PolygonHelper.polygon_predictions(query, type)
    conn |> put_status(:ok) |> json(%{predictions: predictions})
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
