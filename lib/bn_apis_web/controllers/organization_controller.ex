defmodule BnApisWeb.OrganizationController do
  use BnApisWeb, :controller

  alias BnApis.Organizations
  alias BnApis.Organizations.{BrokerRole, Organization}
  alias BnApis.Helpers.{Connection}
  alias BnApisWeb.OrganizationView
  alias BnApis.Helpers.Utils
  require Logger

  action_fallback BnApisWeb.FallbackController

  @doc """
    Team Details
    Requires:

    returns {
      admins: [{
        name: <broker_name>,
        phone_number: <phone_number>,
        profile_url: <profile_url>,
        user_id: <user_id>,
      }, ...],
      chottus: [{
        name: <broker_name>,
        phone_number: <phone_number>,
        profile_url: <profile_url>,
        user_id: <user_id>,
      }, ...],
      pending_invites: [{
        name: <broker_name>,
        phone_number: <phone_number>,
        profile_url: <profile_url>,
        invite_sent_time: <invite_sent_time>
      }]
    }
  """
  def get_team(conn, _params) do
    logged_in_user = Connection.get_logged_in_user(conn)
    organization_id = logged_in_user[:organization_id]

    with {:ok, {admins, chhotus, pendings}} <- Organizations.get_team(organization_id),
         {:ok, pending_requests} <- Organizations.fetch_pending_joining_requests(organization_id, nil) do
      # Pending invites and joining requests only visible to admin
      pendings = if logged_in_user.broker_role_id == BrokerRole.admin().id, do: pendings, else: []
      pending_requests = if logged_in_user.broker_role_id == BrokerRole.admin().id, do: pending_requests, else: []

      render(conn, BnApisWeb.BrokerView, "team.json", admins: admins, chhotus: chhotus, pendings: pendings, pending_requests: pending_requests)
    end
  end

  def get_team_data(conn, params = %{"type" => type}) do
    logged_in_user = Connection.get_logged_in_user(conn)
    organization_id = logged_in_user[:organization_id]
    page = Map.get(params, "page", "1")

    data = Organizations.get_team_data(organization_id, type, String.to_integer(page))
    render(conn, BnApisWeb.BrokerView, "team_pagination.json", type: type, data: data)
  end

  def successor_list(conn, params) do
    logged_in_user = Connection.get_logged_in_user(conn)
    organization_id = logged_in_user[:organization_id]
    page = Map.get(params, "page", "1")

    data = Organizations.successor_list(organization_id, logged_in_user.user_id, params, String.to_integer(page))
    render(conn, BnApisWeb.BrokerView, "team_pagination.json", type: "admin", data: data)
  end

  @doc """
    ONLY ADMINS are allowed to invite admins/members
    Required  %{
      "phone_number" => phone_number,
      "broker_role_id" => broker_role_id,
      "broker_name" => broker_name
    }
  """
  def send_invite(
        conn,
        params = %{
          "phone_number" => _phone_number,
          "broker_role_id" => _broker_role_id,
          "broker_name" => _broker_name
        }
      ) do
    logged_in_user = Connection.get_logged_in_user(conn)

    with {:ok, invite_uuid, message} <- Organizations.send_invite(logged_in_user, params) do
      conn
      |> put_status(:ok)
      |> json(%{message: message, invite_uuid: invite_uuid})
    end
  end

  @doc """
    Resend invites for re-engagement.
    ONLY ADMINS are allowed to invite admins/members

    Required %{
      "user_uuid" => user_uuid,
    }
  """
  def resend_invite(
        conn,
        params = %{
          "invite_uuid" => _invite_uuid
        }
      ) do
    logged_in_user = Connection.get_logged_in_user(conn)

    with {:ok, invite_uuid, message} <- Organizations.resend_invite(logged_in_user, params) do
      conn
      |> put_status(:ok)
      |> json(%{message: message, invite_uuid: invite_uuid})
    end
  end

  @doc """
    Cancel invite
    ONLY ADMINS are allowed to invite admins/members

    Required %{
      "user_uuid" => user_uuid,
    }
  """
  def cancel_invite(
        conn,
        params = %{
          "invite_uuid" => _invite_uuid
        }
      ) do
    logged_in_user = Connection.get_logged_in_user(conn)

    with {:ok, invite_uuid, message} <- Organizations.cancel_invite(logged_in_user, params) do
      conn
      |> put_status(:ok)
      |> json(%{message: message, invite_uuid: invite_uuid})
    end
  end

  def all_organizations(conn, _params) do
    conn
    |> put_status(:ok)
    |> render(OrganizationView, "index.json", %{organizations: Organization.all_active_organizations()})
  end

  def filter_organizations(conn, params) do
    case parse_filter_organizations_params(params) do
      {:ok, query, page, limit} ->
        result_list = Organization.filter_organizations(query, page, limit)
        next = if length(result_list) == limit, do: page + 1, else: -1

        conn
        |> put_status(:ok)
        |> json(%{results: result_list, next: next})

      {:error, _} = error ->
        error
    end
  end

  def fetch_brokers(conn, params = %{"org_uuid" => org_uuid}) do
    role_type_id = Utils.parse_to_integer(Map.get(params, "role_type_id", "1"))
    org_brokers = Organizations.get_organization_brokers(org_uuid, role_type_id)

    conn
    |> put_status(:ok)
    |> json(%{data: org_brokers})
  end

  def create_org_joining_request(conn, params) do
    logged_in_user = Connection.get_logged_in_user(conn)
    requestor_broker_id = logged_in_user.broker_id
    requestor_cred_id = logged_in_user.user_id
    user_map = %{user_id: logged_in_user.user_id, user_type: logged_in_user.user_type}

    with {:ok, joining_request} <- Organizations.create_org_joining_request(params, requestor_broker_id, requestor_cred_id, user_map) do
      conn
      |> put_status(:ok)
      |> json(%{joining_request: Organizations.create_joining_request_map(joining_request)})
    end
  end

  def approve_org_joining_request(conn, _params = %{"joining_request_id" => joining_request_id, "broker_role_id" => broker_role_id}) do
    logged_in_user = Connection.get_logged_in_user(conn)
    processed_by_cred_id = logged_in_user.user_id
    user_map = %{user_id: logged_in_user.user_id, user_type: logged_in_user.user_type}

    with {:ok, _joining_request} <- Organizations.approve_org_joining_request(joining_request_id, broker_role_id, processed_by_cred_id, user_map) do
      conn
      |> put_status(:ok)
      |> json(%{message: "Request approved."})
    end
  end

  def reject_org_joining_request(conn, _params = %{"joining_request_id" => joining_request_id}) do
    logged_in_user = Connection.get_logged_in_user(conn)
    processed_by_cred_id = logged_in_user.user_id
    user_map = %{user_id: logged_in_user.user_id, user_type: logged_in_user.user_type}

    with {:ok, _joining_request} <- Organizations.reject_org_joining_request(joining_request_id, processed_by_cred_id, user_map) do
      conn
      |> put_status(:ok)
      |> json(%{message: "Request rejected."})
    end
  end

  def fetch_joining_request(conn, _params = %{"joining_request_id" => joining_request_id}) do
    orj_joining_request = Organizations.fetch_joining_request(joining_request_id)

    if is_nil(orj_joining_request) do
      conn
      |> put_status(:not_found)
      |> json(%{message: "Joining request not found."})
    else
      conn
      |> put_status(:ok)
      |> json(orj_joining_request)
    end
  end

  def cancel_org_joining_request(conn, _params = %{"joining_request_id" => joining_request_id}) do
    logged_in_user = Connection.get_logged_in_user(conn)
    cred_id = logged_in_user.user_id
    user_map = %{user_id: logged_in_user.user_id, user_type: logged_in_user.user_type}

    with {:ok, _joining_request} <- Organizations.cancel_org_joining_request(joining_request_id, cred_id, user_map) do
      conn
      |> put_status(:ok)
      |> json(%{message: "Request cancelled."})
    end
  end

  def fetch_pending_joining_requests_for_credential(conn, _params) do
    logged_in_user = Connection.get_logged_in_user(conn)
    cred_id = logged_in_user.user_id

    with {:ok, joining_requests} <- Organizations.fetch_pending_org_joining_requests_for_credential(cred_id) do
      conn
      |> put_status(:ok)
      |> json(%{joining_requests: joining_requests})
    end
  end

  def toggle_billing_company_preference(conn, %{"enable" => action}) do
    logged_in_user = Connection.get_logged_in_user(conn)
    user_map = Utils.get_user_map(logged_in_user)

    case Organization.toggle_billing_company_preference(logged_in_user[:user_id], logged_in_user[:broker_role_id], action, user_map) do
      {:ok, org} ->
        conn
        |> put_status(:ok)
        |> json(%{message: "updated", members_can_add_billing_company: org.members_can_add_billing_company})

      error ->
        error
    end
  end

  def toggle_team_upi(conn, %{"enable" => action}) do
    logged_in_user = Connection.get_logged_in_user(conn)
    user_map = Utils.get_user_map(logged_in_user)

    case Organization.toggle_team_upi(logged_in_user[:user_id], logged_in_user[:broker_role_id], user_map, action) do
      {:ok, _org} ->
        conn
        |> put_status(:ok)
        |> json(%{message: "updated"})

      {:error, :incomplete_upi} ->
        conn
        |> put_status(:ok)
        |> json(%{message: "pending upi", incomplete_upi: true})

      error ->
        error
    end
  end

  def get_org_settings(conn, _params) do
    logged_in_user = Connection.get_logged_in_user(conn)

    case Organization.get_org_settings(logged_in_user[:user_id]) do
      {:error, _} = error ->
        error

      result ->
        conn
        |> put_status(:ok)
        |> json(result)
    end
  end

  defp parse_filter_organizations_params(params) do
    query = Map.get(params, "q", "") |> URI.decode()
    page = Map.get(params, "page", "1") |> String.to_integer()
    limit = Map.get(params, "limit", "10") |> String.to_integer()

    if page < 1 or limit > 100 do
      {:error, "invalid page or limit is too large"}
    else
      {:ok, query, page, limit}
    end
  end
end
