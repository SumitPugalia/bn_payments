defmodule BnApis.CustomNotificationWorker do
  alias BnApis.Helpers.{FcmNotification, SmsService, ApplicationHelper}
  alias BnApis.Accounts.Credential

  def perform(title, message, using_sms, using_fcm) do
    credentials = Credential.get_active_broker_credentials()

    fcm_data = %{
      title: title,
      text: message,
      intent: %{
        action: "com.dialectic.brokernetworkapp.actions.OPEN"
      }
    }

    sms_message = title <> "\n" <> message

    credentials
    |> Enum.each(fn cred ->
      cond do
        using_sms && using_fcm ->
          SmsService.send_sms(cred.phone_number, sms_message, false)

          FcmNotification.send_push(
            cred.fcm_id,
            %{data: fcm_data, type: ApplicationHelper.generic_notification_type()},
            cred.id,
            cred.notification_platform
          )

        using_fcm ->
          FcmNotification.send_push(
            cred.fcm_id,
            %{data: fcm_data, type: ApplicationHelper.generic_notification_type()},
            cred.id,
            cred.notification_platform
          )

        true ->
          SmsService.send_sms(cred.phone_number, sms_message, false)
      end
    end)
  end
end
