defmodule BnApis.Rewards.PayoutFailureReason do
  alias BnApis.Helpers.ApplicationHelper

  @retry_payout_worker_time ~T[08:00:00.00]

  @invalid_upi_id [
    "Invalid beneficiary account number",
    "Invalid beneficiary VPA/UPI address",
    "Beneficiary Account is Frozen. Please contact beneficiary bank.",
    "Transaction not permitted to beneficiary account.",
    "Beneficiary Account is Dormant. Please check with Beneficiary Bank.",
    "Invalid beneficiary details.",
    "Invalid Beneficiary PSP. Please check and retry.",
    "Transaction Amount greater than the limit supported by the beneficiary bank."
  ]
  @invalid_upi_id_response %{reason: "Invalid UPI ID, try another account", type: "invalid_details"}

  @bank_server_error [
    "Payout failed at beneficiary bank due to technical issue. Please retry",
    "NPCI or Beneficiary bank systems are offline. Reinitiate transfer after 30 min",
    "NPCI or Beneficiary bank systems are offline. Reinitiate transfer after 30 min.",
    "Temporary Issue at Partner bank. Reinitiate transfer after 30 min.",
    "Beneficiary PSP is down. Please retry after 30 min.",
    "Beneficiary bank is offline. Reinitiate transfer after 30 min.",
    "Payout failed. Reinitiate transfer after 60 min.",
    "Timeout between NPCI and beneficiary bank. Please retry after 30 min.",
    "Payout failed. Contact support for help.",
    "Payout failed. Reinitiate transfer after 30 min.",
    "Technical issue at beneficiary bank. Please retry after 30 mins.",
    nil
  ]
  @bank_server_error_response %{reason: "Bank server did not respond", type: "bank_error"}

  def get_mapped_failure_reason(failure_reason, p_id) do
    cond do
      failure_reason in @invalid_upi_id ->
        Map.merge(@invalid_upi_id_response, %{retry_payout_date: get_retry_date()})

      failure_reason in @bank_server_error ->
        Map.merge(@bank_server_error_response, %{retry_payout_date: get_retry_date()})

      failure_reason not in (@invalid_upi_id ++ @bank_server_error) ->
        send_notification_on_slack(failure_reason, p_id)
        Map.merge(@bank_server_error_response, %{retry_payout_date: get_retry_date()})
    end
  end

  defp send_notification_on_slack(failure_reason, p_id) do
    channel = ApplicationHelper.get_slack_channel()

    ApplicationHelper.notify_on_slack(
      "New Payout Failure Reason Identified: #{failure_reason} for payout: #{p_id}.
      Add it to PaymentFailureReason",
      channel
    )
  end

  defp get_retry_date() do
    now = Timex.now() |> Timex.Timezone.convert("Asia/Kolkata")
    current_time = DateTime.to_time(now)
    current_date = DateTime.to_date(now)
    tomorrow_date = Date.add(current_date, 1)

    case Time.compare(current_time, @retry_payout_worker_time) do
      :gt -> tomorrow_date
      _ -> current_date
    end
  end
end
