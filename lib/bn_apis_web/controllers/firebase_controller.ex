defmodule BnApisWeb.FirebaseController do
  use BnApisWeb, :controller

  alias BnApis.Helpers.{FirebaseHelper, Connection, ApplicationHelper}
  alias BnApis.Accounts.EmployeeRole

  action_fallback BnApisWeb.FallbackController

  plug :access_check,
       [
         allowed_roles: [
           EmployeeRole.super().id,
           EmployeeRole.admin().id
         ]
       ]
       when action in [:update_remote_config]

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

  def remote_config(conn, _params) do
    logged_in_user = Connection.get_logged_in_user(conn)
    config = logged_in_user |> FirebaseHelper.get_remote_config(FirebaseHelper.broker_network_app_name())

    conn
    |> put_status(:ok)
    |> json(config)
  end

  def base_remote_config(conn, _params) do
    config = FirebaseHelper.get_remote_config(nil, FirebaseHelper.broker_network_app_name())

    conn
    |> put_status(:ok)
    |> json(config)
  end

  def builder_base_remote_config(conn, _params) do
    config = FirebaseHelper.basic_remote_configs(FirebaseHelper.broker_builder_app_name())

    conn
    |> put_status(:ok)
    |> json(config)
  end

  def onground_base_remote_config(conn, _params) do
    config = FirebaseHelper.basic_remote_configs(FirebaseHelper.broker_manager_app_name())

    conn
    |> put_status(:ok)
    |> json(config)
  end

  def onground_remote_config(conn, _params) do
    logged_in_user = Connection.get_logged_in_user(conn)
    config = FirebaseHelper.get_remote_config(logged_in_user, FirebaseHelper.broker_manager_app_name())

    conn
    |> put_status(:ok)
    |> json(config)
  end

  def update_remote_config(conn, params = %{"app_name" => app_name}) do
    ApplicationHelper.update_remote_config(params, app_name)

    conn
    |> put_status(:ok)
    |> json(%{message: "updated"})
  end
end
