defmodule BnApis.Projects.NewStoryCreativesPushNotificationWorker do
  import Ecto.Query
  alias BnApis.Repo
  alias BnApis.Helpers.{ApplicationHelper, Utils}
  alias BnApis.Accounts.Credential
  alias BnApis.Organizations.Broker

  def perform(story) do
    channel = ApplicationHelper.get_slack_channel()

    try do
      operating_cities = story.operating_cities

      Broker
      |> where([b], b.role_type_id == ^Broker.real_estate_broker()["id"])
      |> where([b], b.operating_city in ^operating_cities)
      |> Repo.all()
      |> Enum.map(fn broker ->
        send_push_notifications(broker.id, story.name)
      end)
    rescue
      err ->
        ApplicationHelper.notify_on_slack(
          "Error in sending new story creative notification: #{Exception.message(err)} for story_id: #{story.id}",
          channel
        )
    end
  end

  defp send_push_notifications(broker_id, story_name) do
    broker_credential =
      Credential
      |> where([cred], cred.broker_id == ^broker_id)
      |> Repo.all()
      |> Utils.get_active_fcm_credential()

    if not is_nil(broker_credential) do
      {data, type} = get_push_notification_text(story_name)
      trigger_push_notification(broker_credential, %{"data" => data, "type" => type})
    end
  end

  defp get_push_notification_text(story_name) do
    title = "New creative added in #{story_name}"
    message = "Click to view now!"
    intent = "com.dialectic.brokernetworkapp.actions.PROJECT"
    type = "GENERIC_NOTIFICATION"
    data = %{"title" => title, "message" => message, "intent" => intent}
    {data, type}
  end

  defp trigger_push_notification(broker_credential, notif_data = %{"data" => _data, "type" => _type}) do
    Exq.enqueue(Exq, "send_new_story_creatives_notifications", BnApis.Notifications.PushNotificationWorker, [
      broker_credential.fcm_id,
      notif_data,
      broker_credential.id,
      broker_credential.notification_platform
    ])
  end
end
