defmodule Mix.Tasks.FixLatestStatusIdInRewardLeads do
  use Mix.Task
  import Ecto.Query
  alias BnApis.Repo
  alias BnApis.Rewards.RewardsLead
  alias BnApis.Rewards.RewardsLeadStatus

  @shortdoc "fix latest status id in rewards_leads"
  def run(_) do
    Mix.Task.run("app.start", [])
    fix_latest_status_id_in_rewards_leads()
  end

  def update_status_in_rewards_leads(reward_lead) do
    IO.puts("REWARD LEAD - #{reward_lead.id}")

    employee_reward_received_status_id = 5

    latest_non_employee_lead_status =
      RewardsLeadStatus
      |> where([s], s.rewards_lead_id == ^reward_lead.id and s.status_id != ^employee_reward_received_status_id)
      |> order_by([r], desc: r.inserted_at)
      |> limit(1)
      |> Repo.one()

    RewardsLead.update_latest_status!(reward_lead, latest_non_employee_lead_status.id)

    IO.puts("REWARD LEAD LATEST STATUS UPDATED - #{reward_lead.id}")
  end

  def fix_latest_status_id_in_rewards_leads() do
    IO.puts("STARTED THE TASK")

    employee_reward_received_status_id = 5

    RewardsLead
    |> join(:inner, [r], s in RewardsLeadStatus, on: r.latest_status_id == s.id)
    |> where([r, s], s.status_id == ^employee_reward_received_status_id)
    |> Repo.all()
    |> Enum.each(fn reward_lead ->
      reward_lead |> update_status_in_rewards_leads()
    end)

    IO.puts("FINISHED THE TASK")
  end
end
