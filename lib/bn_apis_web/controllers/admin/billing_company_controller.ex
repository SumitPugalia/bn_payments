defmodule BnApisWeb.Admin.BillingCompanyController do
  use BnApisWeb, :controller

  alias BnApis.Organizations.BillingCompany
  alias BnApis.Accounts.EmployeeRole
  alias BnApis.Helpers.Connection
  alias BnApis.Helpers.Utils

  action_fallback BnApisWeb.FallbackController

  plug :access_check,
       [
         allowed_roles: [
           EmployeeRole.super().id,
           EmployeeRole.admin().id,
           EmployeeRole.dsa_super().id,
           EmployeeRole.dsa_admin().id,
           EmployeeRole.invoicing_admin().id
         ]
       ]
       when action in [:mark_as_approved, :mark_as_rejected, :request_changes]

  def all_billing_companies(conn, params) do
    logged_in_user = Connection.get_employee_logged_in_user(conn)
    employee_role_id = logged_in_user.employee_role_id
    user_id = logged_in_user.user_id

    conn
    |> put_status(:ok)
    |> json(BillingCompany.all_billing_companies(params, employee_role_id, user_id))
  end

  def fetch_billing_company(conn, %{"uuid" => uuid}) do
    billing_company = BillingCompany.fetch_billing_company(uuid)

    if is_nil(billing_company) do
      conn
      |> put_status(:not_found)
      |> json(%{message: "Billing Company not found."})
    else
      conn
      |> put_status(:ok)
      |> json(billing_company)
    end
  end

  def mark_as_approved(conn, %{"uuid" => uuid}) do
    user_map = conn |> Connection.get_employee_logged_in_user() |> Utils.get_user_map()

    with {:ok, _billing_company} <- BillingCompany.mark_as_approved(uuid, user_map) do
      conn
      |> put_status(:ok)
      |> json(%{message: "Billing Company Approved."})
    end
  end

  def mark_as_rejected(conn, %{"uuid" => uuid, "change_notes" => change_notes}) do
    with {:ok, _billing_company} <- BillingCompany.mark_as_rejected(uuid, change_notes) do
      conn
      |> put_status(:ok)
      |> json(%{message: "Billing Company Rejected."})
    end
  end

  def request_changes(conn, %{"uuid" => uuid, "change_notes" => change_notes}) do
    with {:ok, _billing_company} <- BillingCompany.request_changes(uuid, change_notes) do
      conn
      |> put_status(:ok)
      |> json(%{message: "Changes Requested for Billing Company."})
    end
  end

  def move_to_pending(conn, %{"uuid" => uuid}) do
    with {:ok, _billing_company} <- BillingCompany.move_to_pending(uuid) do
      conn
      |> put_status(:ok)
      |> json(%{message: "Billing Company moved to pending."})
    end
  end

  ## Private APIs
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
