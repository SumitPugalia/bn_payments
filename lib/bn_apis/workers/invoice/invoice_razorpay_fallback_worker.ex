defmodule BnApis.Workers.Invoice.InvoiceRazorpayFallbackWorker do
  use Ecto.Schema
  import Ecto.Query

  alias BnApis.Repo
  alias BnApis.Rewards.InvoicePayout
  alias BnApis.Accounts.Credential
  alias BnApis.Helpers.ApplicationHelper
  alias BnApis.Helpers.ExternalApiHelper

  @queued "queued"
  @processing_status "processing"

  def perform() do
    channel = ApplicationHelper.get_slack_channel()
    invoice_payouts = get_all_processing_invoices()
    if(length(invoice_payouts) > 0) do
      ApplicationHelper.notify_on_slack(
        "Starting razorpay fallback worker for invoice payout",
        channel
      )

      auth_key = ApplicationHelper.get_razorpay_auth_key()
      invoice_payouts |> Enum.each(fn payout ->
          {status, response} =  ExternalApiHelper.get_razorpay_payout_details(payout.payout_id, auth_key)
          case status do
            200 ->
              InvoicePayout.update_response_body(payout, response)
            _ ->
              change = %{"description" => response["error"]["failure_reason"]}
              InvoicePayout.update_response_body(payout, change)

              ApplicationHelper.notify_on_slack(
                "Issue in getting invoice payout status for invoice_id: #{payout.invoice_id}, razorpay_response:#{Jason.encode!(response)}",
                channel
              )
          end
        end)

      ApplicationHelper.notify_on_slack(
              "Ending razorpay fallback worker for invoice payout",
              channel
            )
    end
  end

  def get_all_processing_invoices() do
    InvoicePayout
    |> join(:inner, [i], cred in Credential, on: i.broker_id == cred.broker_id)
    |> where([i, cred], i.status in [@processing_status, @queued] and cred.active == true and not is_nil(i.payout_id))
    |> where([i], fragment("? > now() - interval '2 hours'", i.updated_at))
    |> Repo.all()
  end
end
