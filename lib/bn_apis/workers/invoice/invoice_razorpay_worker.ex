defmodule BnApis.Workers.Invoice.InvoiceRazorpayWorker do
  use Ecto.Schema

  alias BnApis.Repo
  alias BnApis.Rewards.InvoicePayout
  alias BnApis.PaymentGateway.API, as: PaymentGateway
  alias BnApis.Helpers.ApplicationHelper

  def perform(payout_id) do
    channel = ApplicationHelper.get_slack_channel()
    payout = InvoicePayout |> Repo.get_by(id: payout_id)
    body = InvoicePayout.payout_method(payout)
    {status, response} = PaymentGateway.create_razorpay_payout(payout.fund_account_id,body, payout.id, "g" ,nil)
    case status do
      200 ->
        ApplicationHelper.notify_on_slack(
          "Initiating payment request for invoice_id: #{payout.invoice_id}, razorpay_response:#{Jason.encode!(response)}",
          channel
        )
        InvoicePayout.update_response_body(payout, response)
      _ ->
        ApplicationHelper.notify_on_slack(
          "Issue in creating invoice payout for invoice_id: #{payout.invoice_id}, razorpay_response:#{Jason.encode!(response)}",
          channel
        )
    end
  end
end
