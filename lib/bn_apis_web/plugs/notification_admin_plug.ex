defmodule BnApisWeb.Plugs.NotificationAdminPlug do
  import Plug.Conn
  alias BnApis.Accounts.EmployeeRole

  def init(opts) do
    opts
  end

  defp is_notification_panel_path?(conn) do
    conn.request_path =~ ~r/^\/admin\/campaign\//
  end

  ## Session Plug to restrict notification-admin roles type to only notification panel api's
  def call(conn, _opts) do
    notification_admin_user = conn.assigns[:user]["profile"]["employee_role_id"] == EmployeeRole.notification_admin().id
    is_notification_panel_path = is_notification_panel_path?(conn) || false

    case {notification_admin_user, is_notification_panel_path} do
      {true, true} ->
        conn

      {true, false} ->
        conn
        |> send_resp(401, Poison.encode!(%{message: "You are not authorized to make this call", invalidSession: true}))
        |> halt

      {false, _} ->
        conn
    end
  end
end
