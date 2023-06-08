defmodule BnApisWeb.LegalEntityController do
  use BnApisWeb, :controller

  alias BnApis.Stories.LegalEntity
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
       when action in [:create_legal_entity, :update_legal_entity]

  def all_legal_entities(conn, params) do
    conn
    |> put_status(:ok)
    |> json(LegalEntity.all_legal_entities(params))
  end

  def show(conn, %{"uuid" => uuid}) do
    legal_entity = LegalEntity.fetch_legal_entity(uuid)

    if legal_entity |> is_nil() do
      conn
      |> put_status(:not_found)
      |> json(%{message: "Legal Entity does not exist."})
    else
      conn
      |> put_status(:ok)
      |> json(legal_entity)
    end
  end

  def create_legal_entity(conn, params) do
    logged_in_user = Connection.get_employee_logged_in_user(conn)
    user_map = %{user_id: logged_in_user.user_id, user_type: logged_in_user.user_type}

    with {:ok, legal_entity} <- LegalEntity.create(params, user_map) do
      conn
      |> put_status(:ok)
      |> json(legal_entity)
    end
  end

  def update_legal_entity(conn, params) do
    logged_in_user = Connection.get_employee_logged_in_user(conn)
    user_map = %{user_id: logged_in_user.user_id, user_type: logged_in_user.user_type}

    with {:ok, _legal_entity} <- LegalEntity.update_legal_entity(params, user_map) do
      conn
      |> put_status(:ok)
      |> json(%{message: "Legal Entity successfully updated."})
    end
  end

  def admin_search(conn, params) do
    suggestions = LegalEntity.get_admin_legal_entity_suggestions(params)

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
