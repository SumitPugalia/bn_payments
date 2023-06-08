defmodule Mix.Tasks.ManualChangeStatusInRewardLeads do
  use Mix.Task
  import Ecto.Query
  alias BnApis.Repo
  alias BnApis.Rewards.RewardsLead
  alias BnApis.Rewards.RewardsLeadStatus

  @shortdoc "manual change status in rewards_leads"
  def run(_) do
    Mix.Task.run("app.start", [])
    manual_change_status_in_rewards_leads()
  end

  def update_status_in_rewards_leads(reward_lead) do
    # Pending
    pending_reward_lead_status_id = 1
    # Rejected
    rejected_reward_lead_status_id = 2

    IO.puts("REWARD LEAD - #{reward_lead.id}")
    reward_lead = reward_lead |> Repo.preload(:latest_status)
    latest_status = reward_lead.latest_status

    if not is_nil(latest_status) and latest_status.status_id == pending_reward_lead_status_id do
      RewardsLeadStatus.create_rewards_lead_status_by_backend!(
        reward_lead,
        rejected_reward_lead_status_id
      )

      IO.puts("MOVED TO REJECTED - #{reward_lead.id}")
    else
      IO.puts("LATEST STATUS DOES NOT EXIST OR IS NOT PENDING")
    end
  end

  def manual_change_status_in_rewards_leads() do
    rewards_lead_ids = [
      30365,
      28153,
      27527,
      24748,
      20186,
      20141,
      13928,
      12953,
      12645,
      12098,
      11929,
      11928,
      11927,
      11605,
      11492,
      11491,
      11489,
      11488,
      11474,
      11409,
      11408,
      11407,
      11406,
      11404,
      11402,
      11401,
      11400,
      11399,
      11384,
      11353,
      11331,
      11322,
      11321,
      11320,
      11319,
      11318,
      1647,
      1593,
      1558,
      1549,
      1415,
      1405,
      1382,
      1381,
      1371,
      1370,
      1357,
      1354,
      1352,
      1305,
      1296,
      1295,
      1287,
      1285,
      1249,
      1186,
      1177,
      1160,
      1159,
      967,
      958,
      801,
      752,
      679,
      306
    ]

    IO.puts("STARTED THE TASK")

    RewardsLead
    |> where([r], r.id in ^rewards_lead_ids)
    |> Repo.all()
    |> Enum.each(fn reward_lead ->
      reward_lead |> update_status_in_rewards_leads()
    end)

    IO.puts("FINISHED THE TASK")
  end
end
