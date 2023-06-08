defmodule Mix.Tasks.PopulateEmployeeCredentialIdInRewardLeads do
  use Mix.Task
  import Ecto.Query
  alias BnApis.Repo
  alias BnApis.Rewards.RewardsLead
  alias BnApis.AssignedBrokers

  @shortdoc "populate employee_credential_id in rewards_leads"
  def run(_) do
    Mix.Task.run("app.start", [])
    populate_employee_credential_id_in_rewards_leads()
  end

  def update_employee_credential_id(reward_lead) do
    IO.puts("REWARD LEAD - #{reward_lead.id}")
    broker_id = reward_lead.broker_id
    assigned_broker = AssignedBrokers.fetch_one_broker(broker_id)

    if not is_nil(assigned_broker) do
      ch = RewardsLead.changeset(reward_lead, %{"employee_credential_id" => assigned_broker.employees_credentials_id})
      Repo.update!(ch)
      IO.puts("UPDATED employee_credential_id")
    else
      IO.puts("COULD NOT UPDATE employee_credential_id")
    end
  end

  def populate_employee_credential_id_in_rewards_leads() do
    RewardsLead
    |> where([r], is_nil(r.employee_credential_id))
    |> Repo.all()
    |> Enum.each(fn reward_lead ->
      reward_lead |> update_employee_credential_id()
    end)
  end
end
