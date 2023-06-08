defmodule BnApisWeb.Admin.MandateCompanyController do
  use BnApisWeb, :controller

  alias BnApis.Stories.MandateCompanies
  alias BnApis.Accounts.EmployeeRole
  alias BnApis.Helpers.Connection

  action_fallback BnApisWeb.FallbackController

  plug :access_check,
       [
         allowed_roles: [
           EmployeeRole.super().id,
           EmployeeRole.admin().id,
           EmployeeRole.invoicing_admin().id,
           EmployeeRole.story_admin().id
         ]
       ]
       when action in [:create_mandate_company, :update_mandate_company]

  def all_mandate_companies(conn, params) do
    conn
    |> put_status(:ok)
    |> json(MandateCompanies.all_mandate_companies(params))
  end

  def fetch_mandate_company(conn, %{"id" => id}) do
    mandate_company = MandateCompanies.fetch_mandate_company(id)

    if is_nil(mandate_company) do
      conn
      |> put_status(:not_found)
      |> json(%{message: "Mandate Company not found"})
    else
      conn
      |> put_status(:ok)
      |> json(MandateCompanies.create_mandate_company_map(mandate_company))
    end
  end

  def create_mandate_company(conn, params) do
    logged_in_user = Connection.get_employee_logged_in_user(conn)
    user_map = %{user_id: logged_in_user.user_id, user_type: logged_in_user.user_type}

    with {:ok, mandate_company} <- MandateCompanies.create_mandate_company(params, user_map) do
      conn
      |> put_status(:ok)
      |> json(MandateCompanies.create_mandate_company_map(mandate_company))
    end
  end

  def update_mandate_company(conn, params) do
    logged_in_user = Connection.get_employee_logged_in_user(conn)
    user_map = %{user_id: logged_in_user.user_id, user_type: logged_in_user.user_type}

    with {:ok, mandate_company} <- MandateCompanies.update_mandate_company(params, user_map) do
      conn
      |> put_status(:ok)
      |> json(MandateCompanies.create_mandate_company_map(mandate_company))
    end
  end

  def admin_search_mandate_company(conn, params) do
    with {:ok, suggestions} <- MandateCompanies.admin_search_mandate_company(params) do
      conn
      |> put_status(:ok)
      |> json(%{suggestions: suggestions})
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
