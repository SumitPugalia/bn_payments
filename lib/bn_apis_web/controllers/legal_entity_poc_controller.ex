defmodule BnApisWeb.LegalEntityPocController do
  use BnApisWeb, :controller

  alias BnApis.Stories.LegalEntityPoc
  alias BnApis.Accounts.EmployeeRole
  alias BnApis.Helpers.Connection

  action_fallback BnApisWeb.FallbackController

  plug :access_check,
       [
         allowed_roles: [
           EmployeeRole.super().id,
           EmployeeRole.admin().id,
           EmployeeRole.invoicing_admin().id,
           EmployeeRole.invoicing_operator().id,
           EmployeeRole.finance_admin().id
         ]
       ]
       when action in [:create_legal_entity_poc, :update_legal_entity_poc]

  def all_legal_entity_poc(conn, params) do
    conn
    |> put_status(:ok)
    |> json(LegalEntityPoc.all_legal_entity_poc(params))
  end

  def show(conn, %{"uuid" => uuid}) do
    legal_entity_poc = LegalEntityPoc.fetch_legal_entity_poc(uuid)

    if legal_entity_poc |> is_nil() do
      conn
      |> put_status(:not_found)
      |> json(%{message: "Legal Entity Poc does not exist."})
    else
      conn
      |> put_status(:ok)
      |> json(legal_entity_poc)
    end
  end

  def create_legal_entity_poc(conn, params) do
    with {:ok, legal_entity_poc} <- LegalEntityPoc.create(params) do
      conn
      |> put_status(:ok)
      |> json(legal_entity_poc)
    end
  end

  def update_legal_entity_poc(conn, params) do
    with {:ok, _legal_entity_poc} <- LegalEntityPoc.update_legal_entity_poc(params) do
      conn
      |> put_status(:ok)
      |> json(%{message: "Legal Entity POC successfully updated."})
    end
  end

  def admin_search(conn, %{"q" => query, "poc_type" => poc_type}) do
    suggestions = LegalEntityPoc.get_admin_legal_entity_poc_suggestions(query, poc_type)

    conn
    |> put_status(:ok)
    |> json(%{suggestions: suggestions})
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
