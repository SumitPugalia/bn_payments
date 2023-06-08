defmodule BnApisWeb.V1.CommercialController do
  use BnApisWeb, :controller

  alias BnApis.Helpers.Connection
  alias BnApis.Commercials.CommercialPropertyPost
  alias BnApis.Commercials
  alias BnApis.Accounts.EmployeeRole

  action_fallback BnApisWeb.FallbackController

  plug :access_check,
       [
         allowed_roles: [
           EmployeeRole.super().id,
           EmployeeRole.commercial_qc().id,
           EmployeeRole.commercial_data_collector().id,
           EmployeeRole.commercial_ops_admin().id,
           EmployeeRole.commercial_admin().id,
           EmployeeRole.commercial_agent().id
         ]
       ]
       when action in [:admin_list_post]

  @visit_scheduled "SCHEDULED"
  @visit_deleted "DELETED"

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

  # Panel related API methods

  def admin_get_post(conn, _params = %{"post_uuid" => post_uuid}) do
    logged_in_user = Connection.get_employee_logged_in_user(conn)

    with {:ok, response} <-
           CommercialPropertyPost.admin_get_post(
             post_uuid,
             logged_in_user.user_id,
             logged_in_user.employee_role_id,
             "V1"
           ) do
      conn
      |> put_status(:ok)
      |> json(%{response: response})
    end
  end

  def admin_list_post(conn, params) do
    logged_in_user = Connection.get_employee_logged_in_user(conn)
    params = params |> Map.merge(%{"app_version" => "V1"})

    with {:ok, response} <- Commercials.admin_list_post(params, logged_in_user.user_id, logged_in_user.employee_role_id) do
      conn
      |> put_status(:ok)
      |> json(%{response: response})
    end
  end

  # Below are the App related API methods

  def get_post(conn, %{"post_uuid" => post_uuid}) do
    logged_in_user = Connection.get_logged_in_user(conn)

    with {:ok, response} <- CommercialPropertyPost.get_post(post_uuid, logged_in_user.user_id, nil, "V1") do
      conn
      |> put_status(:ok)
      |> json(%{response: response})
    end
  end

  def list_post(conn, params) do
    logged_in_user = Connection.get_logged_in_user(conn)
    params = params |> Map.merge(%{"app_version" => "V1"})

    with {:ok, response} <- CommercialPropertyPost.list_post(params, logged_in_user.user_id) do
      conn
      |> put_status(:ok)
      |> json(%{response: response})
    end
  end

  def fetch_all_shortlisted_posts(conn, params) do
    logged_in_user = Connection.get_logged_in_user(conn)
    params = params |> Map.merge(%{"app_version" => "V1"})

    with {:ok, response} <- Commercials.fetch_all_shortlisted_posts(params, logged_in_user.user_id) do
      conn
      |> put_status(:ok)
      |> json(%{response: response})
    end
  end

  def list_site_visits_for_broker(conn, params) do
    logged_in_user = Connection.get_logged_in_user(conn)

    with {:ok, page, limit, status_id, visit_start_time, visit_end_time, status_ids} <- parse_filter_list_visit_params(params),
         {:ok, response} <-
           Commercials.list_site_visits_for_broker(page, limit, status_id, visit_start_time, visit_end_time, status_ids, logged_in_user.broker_id, logged_in_user.user_id, "V1") do
      conn
      |> put_status(:ok)
      |> json(%{response: response})
    end
  end

  def create_site_visit(conn, params) do
    logged_in_user = Connection.get_logged_in_user(conn)
    params = params |> Map.merge(%{"app_version" => "V1"})

    with {:ok, data} <- Commercials.create_site_visit(params, logged_in_user.broker_id, logged_in_user.user_id) do
      conn
      |> put_status(:ok)
      |> json(data)
    end
  end

  def update_site_visit(conn, params = %{"visit_id" => visit_id}) do
    logged_in_user = Connection.get_logged_in_user(conn)
    params = params |> Map.merge(%{"app_version" => "V1"})

    with {:ok, response} <-
           Commercials.update_site_visit(
             visit_id,
             params,
             logged_in_user.broker_id,
             logged_in_user.user_id,
             @visit_scheduled
           ) do
      conn
      |> put_status(:ok)
      |> json(response)
    end
  end

  def delete_site_visit(conn, params = %{"visit_id" => visit_id}) do
    logged_in_user = Connection.get_logged_in_user(conn)
    params = params |> Map.merge(%{"app_version" => "V1"})

    with {:ok, response} <-
           Commercials.update_site_visit(
             visit_id,
             params,
             logged_in_user.broker_id,
             logged_in_user.user_id,
             @visit_deleted
           ) do
      conn
      |> put_status(:ok)
      |> json(response)
    end
  end

  defp parse_filter_list_visit_params(params) do
    page = Map.get(params, "p", "1") |> String.to_integer()
    limit = Map.get(params, "limit", "20") |> String.to_integer()
    status_id = Map.get(params, "status_id", "1") |> String.to_integer()
    visit_start_time = Map.get(params, "from", "0") |> String.to_integer()
    visit_end_time = Map.get(params, "to", "0") |> String.to_integer()
    status_ids_json = Jason.decode(Map.get(params, "status_ids", "[]"))

    status_ids =
      case status_ids_json do
        {:ok, data} -> data
        {:error, _} -> []
      end

    if page < 1 or limit > 100 do
      {:error, "invalid page or limit is too large"}
    else
      {:ok, page, limit, status_id, visit_start_time, visit_end_time, status_ids}
    end
  end
end
