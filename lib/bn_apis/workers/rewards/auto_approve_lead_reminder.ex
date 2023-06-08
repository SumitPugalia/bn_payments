defmodule BnApis.Rewards.AutoApproveLeadReminder do
  alias BnApis.Rewards.{RewardsLead, RewardsLeadStatus, Status}
  alias BnApis.Helpers.ApplicationHelper
  alias BnApis.Accounts.DeveloperPocCredential
  alias BnApis.Repo
  alias BnApis.Helpers.Time
  alias BnApis.Rewards.DevPocNotifications
  alias BnApis.Stories.StoryDeveloperPocMapping
  alias BnApis.Stories.Story
  import Ecto.Query

  @sept_26_2022 ~N[2022-09-26 00:00:00]
  @pending_status_id Status.get_status_id("pending")

  @channel ApplicationHelper.get_slack_channel()

  def perform() do
    ApplicationHelper.notify_on_slack(
      "Starting sending Automated SV Rewards Approval Reminders",
      @channel
    )

    send_reminder_for_auto_approved_leads()

    ApplicationHelper.notify_on_slack(
      "Completed sending Automated SV Rewards Approval Reminders",
      @channel
    )
  end

  def send_reminder_for_auto_approved_leads() do
    stream =
      RewardsLead
      |> join(:inner, [rl], s in Story, on: s.id == rl.story_id)
      |> join(:inner, [rl, s], m in StoryDeveloperPocMapping, on: s.id == m.story_id)
      |> join(:inner, [rl, s, m], dev_poc in DeveloperPocCredential, on: m.developer_poc_credential_id == dev_poc.id and dev_poc.active == true)
      |> join(:inner, [rl, s, m, dev_poc], rls in RewardsLeadStatus, on: rls.id == rl.latest_status_id)
      |> where([rl, s, m, dev_poc, rls], rl.inserted_at >= ^@sept_26_2022)
      |> where([rl, s, m, dev_poc, rls], rls.status_id == ^@pending_status_id and rls.inserted_at <= ^Time.get_shifted_time(-48) and rls.inserted_at > ^Time.get_shifted_time(-72))
      |> group_by([rl, s, m, dev_poc, rls], dev_poc.id)
      |> select([rl, s, m, dev_poc, rls], %{
        "lead_count" => count(rl.id),
        "developer_poc_credential_id" => dev_poc.id,
        "developer_poc_credential_fcm_id" => dev_poc.fcm_id,
        "developer_poc_credential_platform" => dev_poc.platform,
        "developer_poc_credential_phone_number" => dev_poc.phone_number
      })
      |> Repo.stream()
      |> Stream.each(fn lead -> DevPocNotifications.send_reminder_notification_to_developer_poc(lead) end)

    Repo.transaction(fn -> Stream.run(stream) end)
  end
end
