defmodule BnApis.Brokers.OrgNotificationWorker do
  import Ecto.Query
  alias BnApis.Helpers.FcmNotification
  alias BnApis.Accounts.Credential
  alias BnApis.Repo
  alias BnApis.Helpers.ApplicationHelper
  alias BnApis.Organizations.Organization

  def perform(cred_id, org_uuid, msg) do
    try do
      broker =
        Credential
        |> join(:inner, [c], b in assoc(c, :broker))
        |> where([c, b], c.id == ^cred_id and c.active == true)
        |> select([c, b], b)
        |> limit(1)
        |> Repo.one()

      title = "Team Settings: Updated by #{broker.name}"

      Organization
      |> join(:inner, [o], c in Credential, on: c.organization_id == o.id)
      |> where([o, c], c.active == true and o.uuid == ^org_uuid and not is_nil(c.fcm_id))
      |> select([o, c], c)
      |> Repo.all()
      |> Enum.each(fn credential ->
        data = %{
          "title" => title,
          "message" => msg,
          "intent" => %{
            "action" => "com.dialectic.brokernetworkapp.actions.PROFILE"
          }
        }

        FcmNotification.send_push(
          credential.fcm_id,
          %{data: data, type: "GENERIC_NOTIFICATION"},
          credential.id,
          credential.notification_platform
        )
      end)
    rescue
      err ->
        channel = ApplicationHelper.get_slack_channel()

        ApplicationHelper.notify_on_slack(
          "Error in OrgNotificationWorker for org_uuid: #{org_uuid}, because of #{Exception.message(err)}",
          channel
        )
    end
  end
end
