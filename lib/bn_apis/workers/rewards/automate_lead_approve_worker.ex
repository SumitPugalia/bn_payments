defmodule BnApis.Rewards.AutomateLeadApproveWorker do
  alias BnApis.Rewards.{RewardsLead, RewardsLeadStatus, Status}
  alias BnApis.Helpers.ApplicationHelper
  alias BnApis.Accounts.DeveloperPocCredential
  alias BnApis.Accounts.Credential
  alias BnApis.Helpers.Time
  alias BnApis.Repo
  import Ecto.Query

  @sept_26_2022 ~N[2022-09-26 00:00:00]
  @pending_status_id Status.get_status_id("pending")
  @approved_status_id Status.get_status_id("approved")
  # @auto_approval_whatsapp_notif_template "builder_3"

  @channel ApplicationHelper.get_slack_channel()

  def perform() do
    ApplicationHelper.notify_on_slack(
      "Automated SV Rewards Approval starting",
      @channel
    )

    # approve_72hrs_old_pending_leads()

    ApplicationHelper.notify_on_slack(
      "Automated SV Rewards Approval completed",
      @channel
    )
  end

  def approve_72hrs_old_pending_leads() do
    stream =
      RewardsLead
      |> where([rl], rl.inserted_at >= ^@sept_26_2022)
      |> join(:inner, [rl], rls in RewardsLeadStatus, on: rls.id == rl.latest_status_id)
      |> where([rl, rls], rls.status_id == ^@pending_status_id and rls.inserted_at < ^Time.get_shifted_time(-72))
      |> Repo.stream()
      |> Stream.each(fn lead -> auto_approve_lead(lead) end)

    Repo.transaction(fn -> Stream.run(stream) end)
  end

  def auto_approve_lead(lead) do
    cred_query = from(c in Credential, where: c.active == true, limit: 1)

    lead =
      Repo.preload(lead, [
        :developer_poc_credential,
        :story,
        broker: [credentials: cred_query]
      ])

    cred = lead.broker.credentials |> List.first()

    if not is_nil(cred) do
      # visit_date = Time.get_formatted_datetime(lead.visit_date, "%d/%m/%Y")

      try do
        bn_approver = DeveloperPocCredential.fetch_bn_approver_credential()
        RewardsLeadStatus.create_rewards_lead_status_by_poc!(lead, @approved_status_id, bn_approver.id)

        # Exq.enqueue(Exq, "dev_poc_notification_queue", BnApis.Rewards.DevPocNotifications, [
        #   @auto_approval_whatsapp_notif_template,
        #   lead.name,
        #   visit_date,
        #   lead.broker.name,
        #   lead.story.name,
        #   lead.developer_poc_credential.id,
        #   lead.developer_poc_credential.fcm_id,
        #   lead.developer_poc_credential.platform,
        #   lead.developer_poc_credential.phone_number,
        #   cred.phone_number
        # ])
      rescue
        err ->
          ApplicationHelper.notify_on_slack(
            "Auto-approve failed for SV reward: #{lead.id}. Error: #{Exception.message(err)}",
            @channel
          )
      end
    end
  end
end
