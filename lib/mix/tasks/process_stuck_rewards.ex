defmodule BnApis.Rewards.ProcessStuckRewards do
  import Ecto.Query
  alias BnApis.Repo
  alias BnApis.Helpers.Time
  alias BnApis.Rewards.RewardsLead
  alias BnApis.Rewards.RewardsLeadStatus

  @queued_status "queued"
  @processed_status "processed"
  @processing_status "processing"

  def perform() do
    process_stuck_rewards()
  end

  defp process_stuck_rewards() do
    {start_time, _end_time} = Time.get_day_beginnning_and_end_time()
    start_time = start_time |> Timex.shift(days: -10)

    Repo.transaction(
      fn ->
        RewardsLead
        |> join(:inner, [rl], rls in RewardsLeadStatus, on: rl.latest_status_id == rls.id)
        |> where([rl, rls], rls.status_id in [3, 4, 5] and rl.inserted_at >= ^start_time)
        |> order_by([rl], desc: rl.inserted_at)
        |> Repo.stream()
        |> Stream.each(fn reward_lead ->
          schedule_payouts(reward_lead)
        end)
        |> Stream.run()
      end,
      timeout: :infinity
    )
  end

  defp schedule_payouts(reward_lead) do
    reward_lead = reward_lead |> Repo.preload([:payouts, :employee_payouts, :latest_status])

    payout_statuses = Enum.map(reward_lead.payouts, fn p -> p.status end)

    broker_payout_done =
      reward_lead.latest_status.status_id == 4 or Enum.member?(payout_statuses, @processed_status) or
        Enum.member?(payout_statuses, @processing_status) or Enum.member?(payout_statuses, @queued_status)

    if not broker_payout_done do
      Exq.enqueue(Exq, "payments", BnApis.Rewards.GeneratePayoutWorker, [reward_lead.id])
    end
  end
end
