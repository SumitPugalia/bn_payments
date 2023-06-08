defmodule BnApisWeb.CommercialController do
  use BnApisWeb, :controller

  alias BnApis.Helpers.{Connection, Utils}
  alias BnApis.Commercials.CommercialPropertyPost
  alias BnApis.Commercials.ContactedCommercialPropertyPost
  alias BnApis.Commercials.CommercialChannelUrlMapping
  alias BnApis.Commercials
  alias BnApis.Accounts.EmployeeRole
  alias BnApis.Helpers.Utils

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

  plug :access_check,
       [
         allowed_roles: [
           EmployeeRole.super().id,
           EmployeeRole.commercial_qc().id,
           EmployeeRole.commercial_data_collector().id,
           EmployeeRole.commercial_ops_admin().id,
           EmployeeRole.commercial_admin().id
         ]
       ]
       when action in [:create_post, :update_post, :create_or_update_poc, :update_status_for_multiple_post]

  @visit_scheduled "SCHEDULED"
  @visit_completed "COMPLETED"
  @visit_cancelled "CANCELLED"
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

  def create_post(conn, params) do
    logged_in_user = Connection.get_employee_logged_in_user(conn)

    with {:ok, post} <- CommercialPropertyPost.create_post(params, logged_in_user.user_id) do
      conn
      |> put_status(:ok)
      |> json(%{commercial_property_post_uuid: post.uuid, commercial_property_post_id: post.id})
    end
  end

  def update_post(
        conn,
        params = %{
          "post_uuid" => _post_uuid
        }
      ) do
    logged_in_user = Connection.get_employee_logged_in_user(conn)

    with {:ok, post} <-
           CommercialPropertyPost.update_post(params, logged_in_user.user_id, logged_in_user.employee_role_id) do
      conn
      |> put_status(:ok)
      |> json(%{
        message: "Post with uuid #{post.uuid} was successfully updated",
        is_status_changed: post.is_status_changed
      })
    end
  end

  def admin_get_post(conn, _params = %{"post_uuid" => post_uuid}) do
    logged_in_user = Connection.get_employee_logged_in_user(conn)

    with {:ok, response} <-
           CommercialPropertyPost.admin_get_post(post_uuid, logged_in_user.user_id, logged_in_user.employee_role_id) do
      conn
      |> put_status(:ok)
      |> json(%{response: response})
    end
  end

  def admin_list_post(conn, params) do
    logged_in_user = Connection.get_employee_logged_in_user(conn)

    with {:ok, response} <- Commercials.admin_list_post(params, logged_in_user.user_id, logged_in_user.employee_role_id) do
      conn
      |> put_status(:ok)
      |> json(%{response: response})
    end
  end

  def create_or_update_poc(conn, params = %{"phone" => phone_number}) do
    with {:ok, response} <- Commercials.create_or_update_poc(phone_number, params) do
      conn
      |> put_status(:ok)
      |> json(%{
        message: "Commercial POC Created or Updated Successfully",
        response: response
      })
    end
  end

  def search_poc(conn, params) do
    with {:ok, data} <- Commercials.search_poc(params) do
      conn
      |> put_status(:ok)
      |> json(data)
    end
  end

  def meta_data(conn, _params) do
    with {:ok, data} <- Commercials.meta_data() do
      conn
      |> put_status(:ok)
      |> json(%{meta_data: data})
    end
  end

  def upload_document(conn, params) do
    logged_in_user = Connection.get_employee_logged_in_user(conn)

    with {:ok, data} <- Commercials.upload_document(params, logged_in_user.user_id) do
      conn
      |> put_status(:ok)
      |> json(data)
    end
  end

  def remove_document(conn, params) do
    with {:ok, data} <- Commercials.remove_document(params) do
      conn
      |> put_status(:ok)
      |> json(data)
    end
  end

  def list_site_visits(conn, params) do
    logged_in_user = Connection.get_employee_logged_in_user(conn)

    with {:ok, response} <- Commercials.list_site_visits(params, logged_in_user.user_id) do
      conn
      |> put_status(:ok)
      |> json(%{response: response})
    end
  end

  def get_site_visit(conn, params = %{"visit_id" => visit_id}) do
    with {:ok, data} <- Commercials.get_site_visit(params, visit_id) do
      conn
      |> put_status(:ok)
      |> json(%{response: data})
    end
  end

  def complete_site_visit(conn, %{"visit_id" => visit_id}) do
    visit_id = if is_binary(visit_id), do: String.to_integer(visit_id), else: visit_id
    logged_in_user = Connection.get_employee_logged_in_user(conn)

    with {:ok, message} <- Commercials.update_site_visit_for_admin(visit_id, logged_in_user.user_id, @visit_completed) do
      conn
      |> put_status(:ok)
      |> json(%{site_visit_id: visit_id, message: message})
    end
  end

  def cancel_site_visit(conn, %{"visit_id" => visit_id}) do
    visit_id = if is_binary(visit_id), do: String.to_integer(visit_id), else: visit_id
    logged_in_user = Connection.get_employee_logged_in_user(conn)

    with {:ok, message} <- Commercials.update_site_visit_for_admin(visit_id, logged_in_user.user_id, @visit_cancelled) do
      conn
      |> put_status(:ok)
      |> json(%{site_visit_id: visit_id, message: message})
    end
  end

  def create_channel_for_admin(conn, _params = %{"post_uuid" => post_uuid, "broker_id" => broker_id}) do
    with {:ok, channel_url} <- Commercials.create_channel(post_uuid, broker_id) do
      conn
      |> put_status(:ok)
      |> json(%{channel_url: channel_url})
    end
  end

  def fetch_channel_info_for_admin(conn, _params = %{"channel_url" => channel_url}) do
    with {_status, response} <- CommercialChannelUrlMapping.get_channel_details(channel_url) do
      conn
      |> put_status(:ok)
      |> json(response)
    end
  end

  def aggregate(conn, params) do
    logged_in_user = Connection.get_employee_logged_in_user(conn)

    with {:ok, data} <- Commercials.aggregate(params, logged_in_user.user_id, logged_in_user.employee_role_id) do
      conn
      |> put_status(:ok)
      |> json(data)
    end
  end

  # Below are the App related API methods

  def get_post(conn, %{"post_uuid" => post_uuid}) do
    logged_in_user = Connection.get_logged_in_user(conn)

    with {:ok, response} <- CommercialPropertyPost.get_post(post_uuid, logged_in_user.user_id) do
      conn
      |> put_status(:ok)
      |> json(%{response: response})
    end
  end

  def list_post(conn, params) do
    logged_in_user = Connection.get_logged_in_user(conn)

    with {:ok, response} <- CommercialPropertyPost.list_post(params, logged_in_user.user_id) do
      conn
      |> put_status(:ok)
      |> json(%{response: response})
    end
  end

  def shortlist_post(
        conn,
        params = %{
          "post_uuid" => _post_uuid
        }
      ) do
    logged_in_user = Connection.get_logged_in_user(conn)
    user_map = Utils.get_user_map(logged_in_user)

    with {:ok, message} <- CommercialPropertyPost.shortlist_post(params, logged_in_user.broker_id, user_map) do
      conn
      |> put_status(:ok)
      |> json(%{message: message})
    end
  end

  def fetch_all_shortlisted_posts(conn, params) do
    logged_in_user = Connection.get_logged_in_user(conn)

    with {:ok, response} <- Commercials.fetch_all_shortlisted_posts(params, logged_in_user.user_id) do
      conn
      |> put_status(:ok)
      |> json(%{response: response})
    end
  end

  def mark_post_contacted(conn, %{"post_uuid" => post_uuid}) do
    logged_in_user = Connection.get_logged_in_user(conn)

    with {:ok, _data} <- ContactedCommercialPropertyPost.add_contacted_details(post_uuid, logged_in_user.user_id) do
      conn
      |> put_status(:ok)
      |> json(%{message: "Contacted details added successsfully"})
    end
  end

  def report_post(
        conn,
        params = %{
          "post_uuid" => post_uuid,
          "reason_id" => reason_id
        }
      ) do
    logged_in_user = Connection.get_logged_in_user(conn)

    with {:ok, post} <- Commercials.report_post(post_uuid, logged_in_user.user_id, reason_id, params["remarks"]) do
      conn
      |> put_status(:ok)
      |> json(%{message: "Post is reported successsfully", post_id: post.commercial_property_post_id})
    end
  end

  def get_document(conn, params = %{"post_uuid" => post_uuid}) do
    with {:ok, data} <- Commercials.get_document(post_uuid, params["is_active"]) do
      conn
      |> put_status(:ok)
      |> json(data)
    end
  end

  def list_site_visits_for_broker(conn, params) do
    logged_in_user = Connection.get_logged_in_user(conn)

    with {:ok, page, limit, status_id, visit_start_time, visit_end_time, status_ids} <- parse_filter_list_visit_params(params),
         {:ok, response} <-
           Commercials.list_site_visits_for_broker(page, limit, status_id, visit_start_time, visit_end_time, status_ids, logged_in_user.broker_id, logged_in_user.user_id) do
      conn
      |> put_status(:ok)
      |> json(%{response: response})
    end
  end

  def create_site_visit(conn, params) do
    logged_in_user = Connection.get_logged_in_user(conn)

    with {:ok, data} <- Commercials.create_site_visit(params, logged_in_user.broker_id, logged_in_user.user_id) do
      conn
      |> put_status(:ok)
      |> json(data)
    end
  end

  def update_site_visit(conn, params = %{"visit_id" => visit_id}) do
    logged_in_user = Connection.get_logged_in_user(conn)

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

  def create_channel_for_broker(conn, _params = %{"post_uuid" => post_uuid}) do
    logged_in_user = Connection.get_logged_in_user(conn)

    with {:ok, channel_url} <- Commercials.create_channel(post_uuid, logged_in_user.broker_id) do
      conn
      |> put_status(:ok)
      |> json(%{channel_url: channel_url})
    end
  end

  def get_report(conn, _params = %{"post_uuid" => post_uuid}) do
    with {:ok, reports} <- Commercials.get_reported_post(post_uuid) do
      conn |> put_status(:ok) |> json(reports)
    end
  end

  def create_bucket(conn, _params = %{"name" => bucket_name}) do
    logged_in_user = Connection.get_logged_in_user(conn)

    with {:ok, data} <- Commercials.create_bucket(bucket_name, logged_in_user.broker_id) do
      conn
      |> put_status(:ok)
      |> json(%{id: data, message: "created successfully"})
    end
  end

  def create_bucket(conn, _params) do
    conn
    |> put_status(:unprocessable_entity)
    |> json(%{message: "Invalid Argument"})
  end

  def list_bucket(conn, params) do
    logged_in_user = Connection.get_logged_in_user(conn)

    with {:ok, response} <- Commercials.list_bucket(params, logged_in_user.broker_id) do
      conn
      |> put_status(:ok)
      |> json(response)
    end
  end

  def list_bucket_status_post(conn, params) do
    logged_in_user = Connection.get_logged_in_user(conn)

    with {:ok, status_id, bucket_id, p, page_size} <- list_bucket_status_post_params(params),
         {:ok, response} <- Commercials.list_bucket_status_post(bucket_id, status_id, p, page_size, logged_in_user.broker_id, logged_in_user.user_id) do
      conn
      |> put_status(:ok)
      |> json(%{response: response})
    end
  end

  def get_bucket(conn, _params = %{"id" => id}) do
    logged_in_user = Connection.get_logged_in_user(conn)

    with {:ok, response} <- Commercials.get_bucket(id, logged_in_user.broker_id) do
      conn
      |> put_status(:ok)
      |> json(response)
    end
  end

  def mark_bucket_viewed(conn, _params = %{"uuid" => uuid}) do
    with {:ok, response} <- Commercials.mark_bucket_viewed(uuid) do
      conn
      |> put_status(:ok)
      |> json(%{id: response})
    end
  end

  def get_bucket_details(conn, _params = %{"bucket_uuid" => bucket_uuid, "token_id" => token_id}) do
    with {:ok, response} <- Commercials.get_bucket_details(bucket_uuid, token_id) do
      conn
      |> put_status(:ok)
      |> json(%{id: response})
    end
  end

  def add_or_remove_post_from_bucket(conn, params) do
    logged_in_user = Connection.get_logged_in_user(conn)

    with {:ok, post_uuid, status_id, bucket_id, is_to_be_added} <- parse_add_post_in_bucket_params(params),
         {:ok, data} <- Commercials.add_or_remove_post_in_bucket(post_uuid, status_id, bucket_id, is_to_be_added, logged_in_user.broker_id) do
      conn
      |> put_status(:ok)
      |> json(data)
    end
  end

  def remove_bucket(conn, _params = %{"bucket_id" => bucket_id}) do
    logged_in_user = Connection.get_logged_in_user(conn)

    with {:ok, message} <- Commercials.remove_bucket(bucket_id, logged_in_user.broker_id) do
      conn
      |> put_status(:ok)
      |> json(%{message: message})
    end
  end

  def remove_bucket_status(conn, _params = %{"bucket_id" => bucket_id, "status_id" => status_id}) do
    logged_in_user = Connection.get_logged_in_user(conn)

    with {:ok, data} <- Commercials.remove_bucket_status(status_id, bucket_id, logged_in_user.broker_id) do
      conn
      |> put_status(:ok)
      |> json(data)
    end
  end

  def update_status_for_multiple_posts(conn, params) do
    logged_in_user = Connection.get_employee_logged_in_user(conn)

    with {:ok, res} <-
           Commercials.update_status_for_multiple_posts(params["post_uuids"], params["comment"], params["status_id"], logged_in_user.user_id, logged_in_user.employee_role_id) do
      conn
      |> put_status(:ok)
      |> json(res)
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

  defp parse_add_post_in_bucket_params(params) do
    post_uuid = Map.get(params, "post_uuid")
    status_id = Map.get(params, "status_id", 1)
    bucket_id = Map.get(params, "id")
    is_to_be_added = Map.get(params, "is_to_be_added", true) |> Utils.parse_boolean_param()

    if is_nil(post_uuid) or is_nil(bucket_id) do
      {:error, "invalid params"}
    else
      {:ok, post_uuid, status_id, bucket_id, is_to_be_added}
    end
  end

  def list_bucket_status_post_params(params) do
    status_id = Map.get(params, "status_id", "1") |> String.to_integer()
    bucket_id = Map.get(params, "id")
    p = Map.get(params, "p", "1") |> String.to_integer()
    page_size = Map.get(params, "page_size", "10") |> String.to_integer()

    if is_nil(status_id) or is_nil(bucket_id) do
      {:error, "invalid params"}
    else
      {:ok, status_id, bucket_id, p, page_size}
    end
  end
end
