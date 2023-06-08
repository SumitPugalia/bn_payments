defmodule BnApis.Rewards.RetryReversedPayoutsWorker do
  alias BnApis.Helpers.ApplicationHelper
  alias BnApis.Rewards.Payout
  alias BnApis.Repo
  alias BnApis.Helpers.Time
  import Ecto.Query

  @reversed_status "reversed"
  @processed_status "processed"
  @processing_status "processing"
  @queued_status "queued"

  def perform() do
    retry_reversed_payouts()
  end

  defp retry_reversed_payouts() do
    channel = ApplicationHelper.get_slack_channel()

    ApplicationHelper.notify_on_slack(
      "Starting to schedule retry for payouts in reversed status",
      channel
    )

    {start_time, _end_time} = Time.get_day_beginnning_and_end_time()
    start_time = start_time |> Timex.shift(days: -100)

    Repo.transaction(
      fn ->
        Payout
        |> where([p], p.status == ^@reversed_status and p.inserted_at >= ^start_time)
        |> Repo.stream()
        |> Stream.each(fn payout ->
          payout = payout |> Repo.preload(rewards_lead: [:latest_status, :payouts])

          try do
            schedule_retry_payout(payout)
          rescue
            _ ->
              ApplicationHelper.notify_on_slack(
                "Error in schedule retry for payout with id: #{payout.id}",
                channel
              )
          end
        end)
        |> Stream.run()
      end,
      timeout: :infinity
    )

    ApplicationHelper.notify_on_slack(
      "Finished to schedule retry for payouts in reversed status",
      channel
    )
  end

  defp schedule_retry_payout(payout) do
    status_list = Enum.map(payout.rewards_lead.payouts, fn p -> p.status end)

    if not Enum.member?(status_list, @processed_status) and
         not Enum.member?(status_list, @processing_status) and
         not Enum.member?(status_list, @queued_status) and
         payout.rewards_lead.latest_status.status_id == 4 do
      Exq.enqueue(Exq, "payments", BnApis.Rewards.GeneratePayoutWorker, [
        payout.rewards_lead_id,
        payout.payout_id
      ])
    end
  end
end
