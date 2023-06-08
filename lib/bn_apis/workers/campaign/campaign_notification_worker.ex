defmodule BnApis.Brokers.CampaignNotificationWorker do
  alias BnApis.Helpers.FcmNotification
  alias BnApis.Campaign.Schema.Campaign
  alias BnApis.Campaign.Schema.CampaignLeads
  alias BnApis.Repo
  alias BnApis.Helpers.ApplicationHelper
  alias BnApis.Accounts.Credential

  import Ecto.Query

  def perform(campaign_id) do
    try do
      now_epoch = DateTime.to_unix(DateTime.utc_now())

      Repo.transaction(
        fn ->
          Campaign
          |> join(:left, [c], assoc(c, :campaign_leads))
          |> join(:left, [c, cl], cred in Credential, on: cred.broker_id == cl.broker_id)
          |> where([c, cl], c.id == ^campaign_id and c.start_date <= ^now_epoch and c.end_date >= ^now_epoch and cl.sent == false)
          |> select([c, cl, cred], {c, cl, cred})
          |> Repo.stream()
          |> Stream.each(fn {c, cl, cred} ->
            if not is_nil(c.data) and not is_nil(cred) and not is_nil(cred.fcm_id) do
              FcmNotification.send_push(
                cred.fcm_id,
                payload(c),
                cred.id,
                cred.notification_platform
              )

              CampaignLeads.changeset(cl, %{sent: true})
              |> Repo.update()

              :ok
            else
              nil
            end
          end)
          |> Stream.run()
        end,
        timeout: :infinity
      )
    rescue
      err ->
        channel = ApplicationHelper.get_slack_channel()

        ApplicationHelper.notify_on_slack(
          "Error in CampaignNotificationWorker for campaign_id: #{campaign_id} because of #{Exception.message(err)} stacktrace: #{inspect(__STACKTRACE__)}",
          channel
        )
    end
  end

  def payload(c) do
    %{data: Map.put(c.data, "campaign_id", c.id) |> Map.put("request_uuid", "#{c.id}"), type: "WEB_ALERT"}
  end
end
