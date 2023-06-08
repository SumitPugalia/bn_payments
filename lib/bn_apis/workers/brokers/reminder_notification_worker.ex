defmodule BnApis.Brokers.ReminderNotificationWorker do
  alias BnApis.Helpers.FcmNotification
  alias BnApis.Accounts.{Credential, EmployeeCredential}
  alias BnApis.Repo
  alias BnApis.Helpers.ApplicationHelper

  def perform(broker_id, employee_id, reminder_date) do
    try do
      credential = Credential.get_credential_from_broker_id(broker_id)
      credential = credential |> Repo.preload(:broker)
      emp_credential = EmployeeCredential.fetch_employee_by_id(employee_id)

      notification_data = get_notification_data(credential.broker.name, reminder_date)

      if not is_nil(notification_data) do
        FcmNotification.send_push(
          emp_credential.fcm_id,
          %{data: notification_data, type: "REMINDER_NOTIFICATION"},
          emp_credential.id,
          emp_credential.notification_platform
        )
      else
        nil
      end
    rescue
      err ->
        channel = ApplicationHelper.get_slack_channel()

        ApplicationHelper.notify_on_slack(
          "Error in ReminderNotificationWorker for employee_id: #{employee_id} abd broker_id: #{broker_id} because of #{Exception.message(err)}",
          channel
        )
    end
  end

  def get_notification_data(broker_name, reminder_date) do
    reminder_time = DateTime.from_unix!(reminder_date) |> Timex.Timezone.convert("Asia/Kolkata") |> Timex.format!("%I:%M %P, %d %b, %Y", :strftime)

    %{
      "title" => "Reminder to connect with #{broker_name}",
      "message" => "Followup with #{broker_name} at #{reminder_time}"
    }
  end
end
