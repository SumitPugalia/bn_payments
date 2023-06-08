defmodule BnApis.NotificationAnalytics do
  import Ecto.Query
  alias BnApis.Repo
  alias BnApis.Helpers.ApplicationHelper

  def perform() do
    success = "success"

    notif_requests =
      Repo.all(
        from r in "notification_requests",
          where: fragment("?::date = current_date", r.inserted_at),
          group_by: r.type,
          select: {r.type, count(r.id)}
      )

    notif_requests_success =
      Repo.all(
        from r in "notification_requests",
          where: fragment("response->'status' = ?", ^success) and fragment("?::date = current_date", r.inserted_at),
          group_by: r.type,
          select: {r.type, count(r.id)}
      )

    channel = ApplicationHelper.get_slack_channel()
    message = notif_requests |> Enum.reduce("", fn data, acc -> "#{elem(data, 0)} - #{elem(data, 1)}, #{acc}" end)

    message_success = notif_requests_success |> Enum.reduce("", fn data, acc -> "#{elem(data, 0)} - #{elem(data, 1)}, #{acc}" end)

    ApplicationHelper.notify_on_slack("Notification requests count for today --->>> #{message}", channel)

    ApplicationHelper.notify_on_slack(
      "Successful notification requests count for today --->>> #{message_success}",
      channel
    )
  end
end
