defmodule BnApisWeb.DeveloperController do
  use BnApisWeb, :controller

  alias BnApis.Accounts.EmployeeRole
  alias BnApis.Developers
  alias BnApis.Helpers.Connection

  plug :access_check,
       [allowed_roles: [EmployeeRole.admin().id, EmployeeRole.super().id]]
       when action in [:create_developer, :update_developer]

  def index(conn, _params) do
    developers = Developers.list_developers()
    render(conn, "index.json", developers: developers)
  end

  def create_developer(conn, params) do
    {status, message_map} =
      case params |> Developers.create_developer() do
        {:ok, developer} ->
          {:ok, %{developer_uuid: developer.uuid}}

        {:error, %Ecto.Changeset{} = changeset} ->
          {:unprocessable_entity, %{errors: inspect(changeset.errors)}}
      end

    conn
    |> put_status(status)
    |> json(message_map)
  end

  def update_developer(conn, params) do
    developer = params["uuid"] |> Developers.get_developer_by_uuid!()

    {status, message_map} =
      case developer |> Developers.update_developer(params) do
        {:ok, developer} ->
          {:ok, %{developer_uuid: developer.uuid}}

        {:error, %Ecto.Changeset{} = changeset} ->
          {:unprocessable_entity, %{errors: inspect(changeset.errors)}}
      end

    conn
    |> put_status(status)
    |> json(message_map)
  end

  def fetch(conn, %{"uuid" => uuid}) do
    developer = uuid |> Developers.get_developer_by_uuid!()
    render(conn, "developer.json", developer: developer)
  end

  def search_developers(conn, %{"q" => search_text, "exclude_developer_uuids" => exclude_developer_uuids}) do
    search_text = search_text |> String.downcase()

    exclude_developer_uuids = if exclude_developer_uuids == "", do: [], else: exclude_developer_uuids |> String.split(",")

    suggestions = Developers.get_developer_suggestions(search_text, exclude_developer_uuids)

    conn
    |> put_status(:ok)
    |> json(%{suggestions: suggestions})
  end

  def search_developers(conn, %{"q" => search_text}) do
    search_text = search_text |> String.downcase()
    suggestions = Developers.get_developer_suggestions(search_text, [])

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
