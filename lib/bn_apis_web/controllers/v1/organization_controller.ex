defmodule BnApisWeb.V1.OrganizationController do
  use BnApisWeb, :controller

  alias BnApis.Organizations
  alias BnApis.Organizations.BrokerRole
  alias BnApis.Helpers.Connection
  require Logger

  action_fallback BnApisWeb.FallbackController

  def get_team(conn, _params) do
    logged_in_user = Connection.get_logged_in_user(conn)
    organization_id = logged_in_user[:organization_id]

    with {:ok, {admins, chhotus, pendings}} <- Organizations.get_team_paginated(organization_id),
         {:ok, pending_requests} <- Organizations.fetch_pending_joining_requests(organization_id, 1) do
      nil_case = %{data: [], next: -1}
      # Pending invites and joining requests only visible to admin
      pendings = if logged_in_user.broker_role_id == BrokerRole.admin().id, do: pendings, else: nil_case
      pending_requests = if logged_in_user.broker_role_id == BrokerRole.admin().id, do: pending_requests, else: nil_case

      render(conn, BnApisWeb.BrokerView, "team_new.json", admins: admins, chhotus: chhotus, pendings: pendings, pending_requests: pending_requests)
    end
  end
end
