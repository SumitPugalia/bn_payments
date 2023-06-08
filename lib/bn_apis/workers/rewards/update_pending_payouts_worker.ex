defmodule BnApis.Rewards.UpdatePendingPayoutsWorker do
  # alias BnApis.Rewards.RewardsLead
  alias BnApis.Helpers.ApplicationHelper
  alias BnApis.Helpers.ExternalApiHelper
  alias BnApis.Rewards.Payout
  alias BnApis.Rewards.EmployeePayout
  alias BnApis.Repo
  import Ecto.Query

  @payout_statuses ["processing", "queued"]

  def perform() do
    update_payouts_statuses()
    update_employee_payouts_statuses()
  end

  defp update_payouts_statuses() do
    channel = ApplicationHelper.get_slack_channel()

    ApplicationHelper.notify_on_slack(
      "Starting to update payouts in processing status",
      channel
    )

    today = Timex.now() |> Timex.Timezone.convert("Asia/Kolkata") |> Timex.beginning_of_day()
    thirty_days_ago = today |> Timex.shift(days: -10) |> Timex.to_naive_datetime()

    latest_processed_payout_ids =
      Payout
      |> where([p], p.status == ^"processed" and p.inserted_at > ^thirty_days_ago)
      |> Repo.all()
      |> Enum.map(& &1.id)

    Payout
    |> where([p], p.status in ^@payout_statuses or p.id in ^latest_processed_payout_ids)
    |> Repo.all()
    |> Enum.each(fn payout ->
      try do
        update_payout(payout)
        Process.sleep(500)
      rescue
        _ ->
          ApplicationHelper.notify_on_slack(
            "Error in updating payout with id: #{payout.id}",
            channel
          )
      end
    end)

    ApplicationHelper.notify_on_slack(
      "Finished to update payouts in processing status",
      channel
    )
  end

  defp update_payout(payout) do
    params = fetch_razorpay_payout_details(payout.payout_id)

    Repo.transaction(fn ->
      try do
        status = params["status"]
        Payout.update_status!(payout, status, params)
      rescue
        _ ->
          Repo.rollback("Unable to update payout")
      end
    end)
  end

  defp update_employee_payouts_statuses() do
    channel = ApplicationHelper.get_slack_channel()

    ApplicationHelper.notify_on_slack(
      "Starting to update employee_payouts in processing status",
      channel
    )

    EmployeePayout
    |> where([ep], ep.status in ^@payout_statuses)
    |> Repo.all()
    |> Enum.each(fn employee_payout ->
      try do
        update_employee_payout(employee_payout)
      rescue
        _ ->
          ApplicationHelper.notify_on_slack(
            "Error in updating employee_payout with id: #{employee_payout.id}",
            channel
          )
      end
    end)

    ApplicationHelper.notify_on_slack(
      "Finished to update employee_payouts in processing status",
      channel
    )
  end

  defp update_employee_payout(employee_payout) do
    params = fetch_razorpay_payout_details(employee_payout.payout_id)

    Repo.transaction(fn ->
      try do
        status = params["status"]
        EmployeePayout.update_status!(employee_payout, status, params)
      rescue
        _ ->
          Repo.rollback("Unable to update employee_payout")
      end
    end)
  end

  defp fetch_razorpay_payout_details(razorpay_payout_id) do
    auth_key = ApplicationHelper.get_razorpay_auth_key()

    {_status_code, response} =
      ExternalApiHelper.get_razorpay_payout_details(
        razorpay_payout_id,
        auth_key
      )

    response
  end
end
