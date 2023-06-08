defmodule BnApis.SendNotificationWorker do
  alias BnApis.Helpers.FcmNotification
  alias BnApis.Accounts.Credential
  alias BnApisWeb.Helpers.NotificationHelper
  alias BnApis.Repo

  def perform(user_id, post_data, perfect_match \\ false) do
    credential = Repo.get(Credential, user_id)
    type = NotificationHelper.get_notification_type_for_match(user_id, perfect_match)

    FcmNotification.send_push(
      credential.fcm_id,
      %{data: post_data, type: type},
      credential.id,
      credential.notification_platform
    )
  end

  def send_team_notification(user_uuid) do
    credential = Repo.get_by(Credential, uuid: user_uuid)
    type = "NEW_TEAM_UPDATE"

    FcmNotification.send_push(
      credential.fcm_id,
      %{data: %{}, type: type},
      credential.id,
      credential.notification_platform
    )
  end
end
