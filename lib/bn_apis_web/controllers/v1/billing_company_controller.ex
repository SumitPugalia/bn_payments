defmodule BnApisWeb.V1.BillingCompanyController do
  use BnApisWeb, :controller

  alias BnApis.Organizations.{BillingCompany, OrgJoiningRequests}
  alias BnApis.Helpers.{Utils, Connection}

  action_fallback BnApisWeb.FallbackController

  @pending_request_message "You have a pending organization joining request, please get it approved before you can proceed with the billing company flow."

  def get_billing_companies_for_broker(conn, params) do
    show_rera_billing_companies_only = Map.get(params, "show_rera_billing_companies_only", "true") |> Utils.parse_boolean_param()

    conn
    |> put_status(:ok)
    |> json(%{
      "billing_companies" => BillingCompany.get_billing_companies_for_broker(conn.assigns[:user], show_rera_billing_companies_only),
      "failed_billing_companies_count" => BillingCompany.get_change_requested_billing_company_count(conn.assigns[:user]["profile"]["broker_id"])
    })
  end

  def create_billing_company(conn, params) do
    logged_in_user = Connection.get_logged_in_user(conn)
    cred_id = logged_in_user.user_id
    organization_id = logged_in_user.organization_id

    case BillingCompany.maybe_create_billing_company(params, logged_in_user.broker_id, logged_in_user.broker_role_id, organization_id) do
      {:ok, conflicts} when is_list(conflicts) and length(conflicts) > 0 ->
        has_pending_joining_request = OrgJoiningRequests.multiple_joining_request?(cred_id)

        conn
        |> put_status(:ok)
        |> json(%{conflicts: conflicts, has_pending_joining_request: has_pending_joining_request, pending_request_message: @pending_request_message})

      {:ok, billing_company} ->
        conn
        |> put_status(:ok)
        |> json(billing_company)

      {:error, error} ->
        {:error, error}
    end
  end
end
