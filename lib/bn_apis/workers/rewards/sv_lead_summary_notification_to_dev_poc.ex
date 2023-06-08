defmodule BnApis.Rewards.SvLeadSummaryNotificationToDevPoc do
  alias BnApis.Rewards.{RewardsLead, RewardsLeadStatus, Status}
  alias BnApis.Helpers.{ApplicationHelper, Time}
  alias BnApis.Accounts.DeveloperPocCredential
  alias BnApis.Repo
  alias BnApis.Stories.Story
  alias BnApis.Rewards.DevPocNotifications
  alias BnApis.Stories.StoryDeveloperPocMapping
  import Ecto.Query

  @channel ApplicationHelper.get_slack_channel()
  @pending_status_id Status.get_status_id("pending")
  @in_review_status_id Status.get_status_id("in_review")

  def perform() do
    ApplicationHelper.notify_on_slack(
      "Starting sending SV Rewards Summary",
      @channel
    )

    send_summary_notification()

    ApplicationHelper.notify_on_slack(
      "SV Rewards Summary sent",
      @channel
    )
  end

  def send_summary_notification() do
    stream =
      RewardsLead
      |> join(:inner, [rl], rls in RewardsLeadStatus, on: rls.id == rl.latest_status_id)
      |> join(:inner, [rl, rls], s in Story, on: rl.story_id == s.id)
      |> join(:inner, [rl, rls, s], m in StoryDeveloperPocMapping, on: m.story_id == s.id)
      |> join(:inner, [rl, rls, s, m], dev_poc in DeveloperPocCredential, on: m.developer_poc_credential_id == dev_poc.id and dev_poc.active == true)
      |> where([rl, rls, s, m, dev_poc], m.active == true and rls.status_id in [@pending_status_id, @in_review_status_id] and rl.inserted_at >= ^Time.get_start_of_day())
      |> group_by([rl, rls, s, m, dev_poc], dev_poc.id)
      |> select([rl, rls, s, m, dev_poc], %{
        "lead_count" => count(rl.id),
        "developer_poc_credential_id" => dev_poc.id,
        "developer_poc_credential_fcm_id" => dev_poc.fcm_id,
        "developer_poc_credential_platform" => dev_poc.platform,
        "developer_poc_credential_phone_number" => dev_poc.phone_number
      })
      |> Repo.stream()
      |> Stream.each(fn lead ->
        DevPocNotifications.send_summary_notification_to_developer_poc(lead["lead_count"], lead, get_story_names(lead["lead_count"], lead["developer_poc_credential_id"]))
      end)

    Repo.transaction(fn -> Stream.run(stream) end)
  end

  defp get_story_names(0, _dev_poc_cred_id), do: ""

  defp get_story_names(_, dev_poc_cred_id) do
    RewardsLead
    |> join(:inner, [rl], rls in RewardsLeadStatus, on: rls.id == rl.latest_status_id)
    |> join(:inner, [rl, rls], dev_poc in DeveloperPocCredential, on: rl.developer_poc_credential_id == ^dev_poc_cred_id)
    |> join(:inner, [rl, rls, dev_poc], s in Story, on: rl.story_id == s.id)
    |> where([rl, rls, dev_poc, s], rls.status_id in [@pending_status_id, @in_review_status_id] and rl.inserted_at >= ^Time.get_start_of_day())
    |> distinct([rl, rls, dev_poc, s], s.name)
    |> select([rl, rls, dev_poc, s], s.name)
    |> Repo.all()
    |> create_story_names_string()
  end

  defp create_story_names_string(story_names_list) do
    story_names_list |> Enum.reduce("", fn story_name, acc -> concat_story_name(story_name, acc) end)
  end

  defp concat_story_name(story_name, ""), do: story_name
  defp concat_story_name(story_name, acc), do: acc <> ", " <> story_name
end
