defmodule BnApisWeb.NotificationController do
  use BnApisWeb, :controller
  alias BnApisWeb.Helpers.NotificationHelper
  alias BnApis.Helpers.Connection

  action_fallback(BnApisWeb.FallbackController)

  def update_status(conn, %{"uuids" => uuids}) do
    uuids
    |> String.split(",")
    |> NotificationHelper.update_request_status()

    conn |> put_status(:ok) |> json(%{message: "Success"})
  end

  def poll(conn, _params) do
    logged_in_user = conn |> Connection.get_logged_in_user()
    requests = logged_in_user[:user_id] |> NotificationHelper.poll()

    conn
    |> put_status(:ok)
    |> render(BnApisWeb.NotificationView, "index.json", %{notifications: requests})
  end
end
