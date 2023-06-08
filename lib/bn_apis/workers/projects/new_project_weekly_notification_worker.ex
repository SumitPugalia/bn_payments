defmodule BnApis.Projects.NewProjectsWeeklyNotificationWorker do
  import Ecto.Query
  alias BnApis.Repo
  alias BnApis.Helpers.ApplicationHelper
  alias BnApis.Accounts.Credential
  alias BnApis.Organizations.Broker
  alias BnApis.Places.City
  alias BnApis.Stories.Story

  @starting_msg "Starting to send new projects in last week notifications"
  @completion_msg "Finished sending new projects in last week notifications for user"

  def perform() do
    channel = ApplicationHelper.get_slack_channel()

    try do
      ApplicationHelper.notify_on_slack(
        @starting_msg,
        channel
      )

      City
      |> Repo.all()
      |> Enum.each(fn city ->
        send_notifications(city.id)
      end)

      ApplicationHelper.notify_on_slack(
        @completion_msg,
        channel
      )
    rescue
      err ->
        ApplicationHelper.notify_on_slack(
          "Error in sending new projects notification: #{Exception.message(err)}",
          channel
        )
    end
  end

  defp send_notifications(city_id) do
    {starting_interval, ending_interval} = get_time_interval()
    num_of_projects = get_num_of_projects(city_id, starting_interval, ending_interval)

    if num_of_projects > 0 do
      broker_credentials = get_broker_credentials(city_id)

      if length(broker_credentials) > 0 do
        {data, type} = get_notification_text(num_of_projects)
        push_notification(broker_credentials, %{"data" => data, "type" => type})
      end
    end
  end

  defp get_time_interval() do
    today = Timex.now() |> Timex.Timezone.convert("Asia/Kolkata")
    ending_interval = Timex.beginning_of_day(today)
    starting_interval = Timex.shift(ending_interval, days: -7)
    {starting_interval, ending_interval}
  end

  defp get_num_of_projects(city_id, starting_interval, ending_interval) do
    Story
    |> where([s], ^city_id in s.operating_cities)
    |> where([s], s.inserted_at >= ^starting_interval)
    |> where([s], s.inserted_at < ^ending_interval)
    |> Repo.aggregate(:count, :id)
  end

  defp get_broker_credentials(city_id) do
    Credential
    |> join(:inner, [c], b in Broker, on: b.id == c.broker_id)
    |> where([c, b], c.active == true)
    |> where([c, b], not is_nil(c.fcm_id) and b.operating_city == ^city_id)
    |> Credential.filter_by_broker_role_type(false)
    |> Repo.all()
  end

  defp get_notification_text(num_of_projects) do
    title = "#{num_of_projects} new projects added this week"
    message = "Explore projects in your area now!"
    intent = "com.dialectic.brokernetworkapp.actions.PROJECT"
    type = "GENERIC_NOTIFICATION"
    data = %{"title" => title, "message" => message, "intent" => intent}
    {data, type}
  end

  defp push_notification(broker_credentials, notif_data = %{"data" => _data, "type" => _type}) do
    broker_credentials
    |> Enum.each(fn credential ->
      Exq.enqueue(Exq, "send_new_project_notifications", BnApis.Notifications.PushNotificationWorker, [
        credential.fcm_id,
        notif_data,
        credential.id,
        credential.notification_platform
      ])
    end)
  end
end
