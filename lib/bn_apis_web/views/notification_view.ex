defmodule BnApisWeb.NotificationView do
  use BnApisWeb, :view
  alias BnApisWeb.NotificationView

  def render("index.json", %{notifications: notifications}) do
    %{data: render_many(notifications, NotificationView, "show.json", %{})}
  end

  def render("show.json", %{notification: notification}) do
    %{
      type: notification.type,
      data: notification.payload["data"],
      request_uuid: notification.request_uuid,
      fcm_id: notification.fcm_id
    }
  end
end
