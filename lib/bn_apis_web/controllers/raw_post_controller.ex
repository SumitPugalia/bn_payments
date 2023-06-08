defmodule BnApisWeb.RawPostController do
  use BnApisWeb, :controller

  alias BnApis.Posts.{RawRentalPropertyPost, RawResalePropertyPost}
  alias BnApis.Accounts.EmployeeRole
  alias BnApis.Helpers.Connection
  alias BnApis.Helpers.Utils

  action_fallback BnApisWeb.FallbackController

  plug :access_check,
       [
         allowed_roles: [
           EmployeeRole.super().id,
           EmployeeRole.owner_supply_admin().id,
           EmployeeRole.owner_supply_operations().id,
           EmployeeRole.owner_call_center_agent().id,
           EmployeeRole.owner_call_center_admin().id
         ]
       ]
       when action in [:mark_as_junk]

  plug :access_check,
       [allowed_roles: [EmployeeRole.super().id, EmployeeRole.broker_admin().id, EmployeeRole.owner_supply_admin().id]]
       when action in [:download_csv]

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

  def overview(conn, params = %{"property_type" => "rental"}) do
    with {data} <- RawRentalPropertyPost.get_overview(params) do
      conn
      |> put_status(:ok)
      |> json(data)
    end
  end

  def overview(conn, params = %{"property_type" => "resale"}) do
    with {data} <- RawResalePropertyPost.get_overview(params) do
      conn
      |> put_status(:ok)
      |> json(data)
    end
  end

  def index(conn, params = %{"property_type" => "rental"}) do
    with {data} <- RawRentalPropertyPost.get_data(params) do
      conn
      |> put_status(:ok)
      |> json(data)
    end
  end

  def index(conn, params = %{"property_type" => "resale"}) do
    with {data} <- RawResalePropertyPost.get_data(params) do
      conn
      |> put_status(:ok)
      |> json(data)
    end
  end

  def download_csv(conn, params = %{"property_type" => "rental"}) do
    conn
    |> put_resp_content_type("text/csv")
    |> put_resp_header("content-disposition", "attachment; filename=\"raw_rental_posts.csv\"")
    |> send_resp(200, params |> RawRentalPropertyPost.build_export_query())
  end

  def download_csv(conn, params = %{"property_type" => "resale"}) do
    conn
    |> put_resp_content_type("text/csv")
    |> put_resp_header("content-disposition", "attachment; filename=\"raw_resale_posts.csv\"")
    |> send_resp(200, params |> RawResalePropertyPost.build_export_query())
  end

  def create(conn, params = %{"property_type" => "rental"}) do
    params = transform_params(params)

    with {raw_rental_property_post} <- RawRentalPropertyPost.create(params) do
      conn
      |> put_status(:ok)
      |> json(raw_rental_property_post)
    end
  end

  def create(conn, params = %{"property_type" => "resale"}) do
    params = transform_params(params)

    with {raw_resale_property_post} <- RawResalePropertyPost.create(params) do
      conn
      |> put_status(:ok)
      |> json(raw_resale_property_post)
    end
  end

  def fetch(conn, params = %{"property_type" => "rental", "uuid" => _uuid}) do
    with {:ok, raw_rental_property_post} <- RawRentalPropertyPost.fetch_post(params) do
      conn
      |> put_status(:ok)
      |> json(raw_rental_property_post)
    end
  end

  def fetch(conn, params = %{"property_type" => "resale", "uuid" => _uuid}) do
    with {:ok, raw_resale_property_post} <- RawResalePropertyPost.fetch_post(params) do
      conn
      |> put_status(:ok)
      |> json(raw_resale_property_post)
    end
  end

  def update(conn, params = %{"property_type" => "rental", "uuid" => _uuid}) do
    params = transform_params(params)
    logged_in_user = Connection.get_employee_logged_in_user(conn)
    user_map = Utils.get_user_map(logged_in_user)

    with {raw_rental_property_post} <- RawRentalPropertyPost.update_post(user_map, params) do
      conn
      |> put_status(:ok)
      |> json(raw_rental_property_post)
    end
  end

  def update(conn, params = %{"property_type" => "resale", "uuid" => _uuid}) do
    params = transform_params(params)
    logged_in_user = Connection.get_employee_logged_in_user(conn)
    user_map = Utils.get_user_map(logged_in_user)

    with {raw_resale_property_post} <- RawResalePropertyPost.update_post(user_map, params) do
      conn
      |> put_status(:ok)
      |> json(raw_resale_property_post)
    end
  end

  def mark_as_junk(conn, params = %{"property_type" => "rental", "uuid" => _uuid, "reason" => _reason}) do
    logged_in_user = Connection.get_employee_logged_in_user(conn)
    user_map = Utils.get_user_map(logged_in_user)

    with {raw_rental_property_post} <- RawRentalPropertyPost.mark_as_junk(user_map, params) do
      conn
      |> put_status(:ok)
      |> json(raw_rental_property_post)
    end
  end

  def mark_as_junk(conn, params = %{"property_type" => "resale", "uuid" => _uuid, "reason" => _reason}) do
    logged_in_user = Connection.get_employee_logged_in_user(conn)
    user_map = Utils.get_user_map(logged_in_user)

    with {raw_resale_property_post} <- RawResalePropertyPost.mark_as_junk(user_map, params) do
      conn
      |> put_status(:ok)
      |> json(raw_resale_property_post)
    end
  end

  def update_disposition(conn, params = %{"property_type" => "rental", "uuid" => _uuid, "disposition" => _disposition}) do
    logged_in_user = Connection.get_employee_logged_in_user(conn)
    user_map = Utils.get_user_map(logged_in_user)

    with {raw_rental_property_post} <- RawRentalPropertyPost.update_disposition(user_map, params) do
      conn
      |> put_status(:ok)
      |> json(raw_rental_property_post)
    end
  end

  def update_disposition(conn, params = %{"property_type" => "resale", "uuid" => _uuid, "disposition" => _disposition}) do
    logged_in_user = Connection.get_employee_logged_in_user(conn)
    user_map = Utils.get_user_map(logged_in_user)

    with {raw_resale_property_post} <- RawResalePropertyPost.update_disposition(user_map, params) do
      conn
      |> put_status(:ok)
      |> json(raw_resale_property_post)
    end
  end

  defp transform_params(params) do
    params
    |> handle_utm_map_in_params()
    |> handle_source_in_params()
  end

  defp handle_utm_map_in_params(params) do
    if not is_nil(params["utm_map"]) do
      params
      |> Map.merge(%{
        "gclid" => params["gclid"] || params["utm_map"]["gclid"],
        "fbclid" => params["fbclid"] || params["utm_map"]["fbclid"],
        "utm_medium" => params["utm_medium"] || params["utm_map"]["utm_medium"],
        "utm_source" => params["utm_source"] || params["utm_map"]["utm_source"],
        "utm_campaign" => params["utm_campaign"] || params["utm_map"]["utm_campaign"]
      })
    else
      params
    end
  end

  defp handle_source_in_params(params) do
    cond do
      not is_nil(params["gclid"]) ->
        params |> Map.merge(%{"source" => "google"})

      not is_nil(params["fbclid"]) ->
        params |> Map.merge(%{"source" => "facebook"})

      true ->
        params
    end
  end
end
