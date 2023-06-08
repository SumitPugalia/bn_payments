defmodule Mix.Tasks.AddEmployeePenaltyFlagToRewardsLead do
  use Mix.Task
  alias BnApis.Repo
  import Ecto.Query
  alias BnApis.Rewards.RewardsLead

  @shortdoc "Add employee penalty flag to rewards lead"
  def run(_) do
    Mix.Task.run("app.start", [])
    process_rewards_leads()
  end

  def process_rewards_leads() do
    {_, reward_start_date} = NaiveDateTime.new(~D[2022-04-11], ~T[00:00:00.000])
    {_, reward_end_date} = NaiveDateTime.new(~D[2022-08-09], ~T[00:00:00.000])

    all_applicable_rewards_query = RewardsLead |> where([rl], rl.visit_date > ^reward_start_date and rl.visit_date < ^reward_end_date and rl.release_employee_payout == true)
    all_applicable_rewards = all_applicable_rewards_query |> Repo.all()
    all_unique_employees = all_applicable_rewards |> Enum.map(& &1.employee_credential_id) |> Enum.uniq() |> Enum.filter(&(not is_nil(&1)))

    all_unique_employees
    |> Enum.each(fn emp_id ->
      all_rewards_for_employee = all_applicable_rewards_query |> where([rl], rl.employee_credential_id == ^emp_id) |> Repo.all() |> Repo.preload(:latest_status)
      rejected_rewards = all_rewards_for_employee |> Enum.filter(fn rl -> rl.latest_status.status_id == 2 end)
      approved_rewards = all_rewards_for_employee |> Enum.filter(fn rl -> Enum.member?([3, 4, 5], rl.latest_status.status_id) end)

      to_be_penalized_approved_rewards_count = (rejected_rewards |> length) * 2
      approved_rewards_to_update = approved_rewards |> Enum.take(to_be_penalized_approved_rewards_count)

      approved_rewards_to_update
      |> Enum.each(fn rl ->
        rl |> RewardsLead.changeset(%{"has_employee_penalty" => true}) |> Repo.update!()
      end)
    end)
  end
end
