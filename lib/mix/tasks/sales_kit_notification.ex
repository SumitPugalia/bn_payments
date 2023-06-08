defmodule Mix.Tasks.SalesKitNotification do
  use Mix.Task

  @data %{
    title: "10 New Launches in Pune",
    text: "Get sales kits personalised for you to share with your clients",
    intent: %{
      action: "com.dialectic.brokernetworkapp.actions.STORIES"
    }
  }

  @shortdoc "notification for personalised sales kit"
  def run(_) do
    Mix.Task.run("app.start", [])

    BnApis.Accounts.Credential.get_active_broker_credentials()
    |> Enum.each(&send_notification/1)
  end

  def send_notification(cred) do
    BnApis.Helpers.FcmNotification.send_push(
      cred.fcm_id,
      %{data: @data, type: "GENERIC_NOTIFICATION"},
      cred.id,
      cred.notification_platform
    )
  end
end
