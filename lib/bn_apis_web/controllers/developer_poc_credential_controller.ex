defmodule BnApisWeb.DeveloperPocCredentialController do
  use BnApisWeb, :controller

  alias BnApis.Repo
  alias BnApis.Accounts.DeveloperPocCredential
  alias BnApis.Accounts.EmployeeRole
  alias BnApis.Helpers.{Connection, Utils}
  alias BnApisWeb.Helpers.PhoneHelper, as: Phone

  action_fallback(BnApisWeb.FallbackController)

  plug(
    :access_check,
    [allowed_roles: [EmployeeRole.super().id, EmployeeRole.admin().id]]
    when action in [:create_developer_poc, :update_developer_poc]
  )

  def create_developer_poc(conn, params) do
    logged_in_user = Connection.get_employee_logged_in_user(conn)
    user_map = Utils.get_user_map(logged_in_user)

    with {:ok, phone_number, country_code} <- Phone.parse_phone_number(params),
         nil <- DeveloperPocCredential.fetch_developer_poc_credential(phone_number, country_code),
         {:ok, %DeveloperPocCredential{} = developer_poc_credential} <-
           params
           |> Map.merge(%{"phone_number" => phone_number, "country_code" => country_code})
           |> DeveloperPocCredential.signup_user(user_map) do
      conn
      |> put_status(:ok)
      |> render(BnApisWeb.CredentialView, "developer_poc.json", %{
        developer_poc: developer_poc_credential
      })
    else
      {:error, _reason} = error ->
        error

      %DeveloperPocCredential{} ->
        {:error, "Developer POC with phone_number already exists!!"}
    end
  end

  def update_developer_poc(conn, params) do
    logged_in_user = Connection.get_employee_logged_in_user(conn)
    user_map = Utils.get_user_map(logged_in_user)

    case Repo.get_by(DeveloperPocCredential, id: params["id"]) do
      nil ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{message: "Developer POC does not exist!!"})

      developer_poc_credential ->
        {:ok, developer_poc_credential} = DeveloperPocCredential.update(developer_poc_credential, params, user_map)

        conn
        |> put_status(:ok)
        |> render(BnApisWeb.CredentialView, "developer_poc.json", %{
          developer_poc: developer_poc_credential
        })
    end
  end

  def all_developer_pocs(conn, _params) do
    data =
      BnApisWeb.CredentialView.render("developer_pocs_data.json", %{
        data: DeveloperPocCredential.all_developer_pocs()
      })

    conn
    |> put_status(:ok)
    |> json(%{data: data})
  end

  def search_developer_pocs(conn, params) do
    response = DeveloperPocCredential.search_developer_pocs(params)

    conn
    |> put_status(:ok)
    |> json(response)
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
