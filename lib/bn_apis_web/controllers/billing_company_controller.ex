defmodule BnApisWeb.BillingCompanyController do
  use BnApisWeb, :controller

  alias BnApis.Organizations.BillingCompany
  alias BnApis.Organizations.Organization
  alias BnApis.Organizations.BrokerRole
  alias BnApis.Helpers.Connection
  alias BnApis.Helpers.Utils

  action_fallback BnApisWeb.FallbackController

  def get_billing_companies_for_broker(conn, params) do
    show_rera_billing_companies_only = Map.get(params, "show_rera_billing_companies_only", "true") |> Utils.parse_boolean_param()

    conn
    |> put_status(:ok)
    |> json(BillingCompany.get_billing_companies_for_broker(conn.assigns[:user], show_rera_billing_companies_only))
  end

  def get_billing_companies_for_broker_v1(conn, params) do
    show_rera_billing_companies_only = Map.get(params, "show_rera_billing_companies_only", "true") |> Utils.parse_boolean_param()
    logged_in_user = Connection.get_logged_in_user(conn)

    org = Organization.get_organization_from_cred(logged_in_user.user_id)
    can_create = if logged_in_user.broker_role_id == BrokerRole.admin().id, do: true, else: org.members_can_add_billing_company

    conn
    |> put_status(:ok)
    |> json(%{
      "can_create_billing_companies" => can_create,
      "billing_companies" => BillingCompany.get_billing_companies_for_broker(conn.assigns[:user], show_rera_billing_companies_only),
      "failed_billing_companies_count" => BillingCompany.get_change_requested_billing_company_count(conn.assigns[:user]["profile"]["broker_id"])
    })
  end

  def fetch_billing_company(conn, %{"uuid" => uuid}) do
    billing_company = BillingCompany.fetch_billing_company(uuid)

    if billing_company |> is_nil() do
      conn
      |> put_status(:not_found)
      |> json(%{message: "Billing Company not found."})
    else
      conn
      |> put_status(:ok)
      |> json(billing_company)
    end
  end

  def create_billing_company(conn, _params) do
    ## Deprecating the Old version of billing company create api, to make sure we don't allow duplicate details
    ## to be entered in older app versions
    conn
    |> put_status(:unprocessable_entity)
    |> json(%{message: "There has been a change in Billing Company creation flow, please update your app to access the latest changes."})
  end

  def update_billing_company(conn, params) do
    broker_id = conn.assigns[:user] |> get_in(["profile", "broker_id"])

    with {:ok, _billing_company} <- BillingCompany.update_billing_company(params, broker_id) do
      conn
      |> put_status(:ok)
      |> json(%{message: "Billing Company successfully updated."})
    end
  end

  def delete_billing_company(conn, %{"uuid" => uuid}) do
    broker_id = conn.assigns[:user] |> get_in(["profile", "broker_id"])

    with {:ok, _billing_company} <- BillingCompany.delete_billing_company(uuid, broker_id) do
      conn
      |> put_status(:ok)
      |> json(%{message: "Billing Company Successfully deleted."})
    end
  end
end
