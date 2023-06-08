defmodule BnApis.Helpers.RazorpayWebhookHelper do
  # alias BnApis.Rewards
  alias BnApis.Subscriptions
  alias BnApis.Orders
  alias BnApis.Rewards.InvoicePayout
  alias BnApis.Helpers.ApplicationHelper

  # @payout "payout"
  @invoice_payout "payout"
  @subscription "subscription"
  @payment "payment"
  @order "order"

  def handle_razorpay_webhook(razorpay_event_id, payload) do
    payload_contains = payload["contains"]

    if Enum.member?(payload_contains, @subscription) do
      handle_subscription_webhook(razorpay_event_id, payload)
    end

    if Enum.member?(payload_contains, @order) do
      handle_order_webhook(razorpay_event_id, payload)
    end

    if Enum.member?(payload_contains, @payment) do
      handle_payment_webhook(razorpay_event_id, payload)
    end

    if Enum.member?(payload_contains, @invoice_payout) do
      handle_invoice_payout_webhook(razorpay_event_id, payload)
    end

    %{"message" => "Success"}
  end

  def handle_subscription_webhook(razorpay_event_id, payload) do
    params = payload["payload"]["subscription"]["entity"]
    subscription_id = params["id"]

    subscription_params = %{
      status: params["status"],
      razorpay_data: payload,
      created_at: params["created_at"],
      razorpay_customer_id: params["customer_id"],
      razorpay_event_id: razorpay_event_id,
      short_url: params["short_url"],
      payment_method: params["payment_method"],
      start_at: params["start_at"],
      ended_at: params["ended_at"],
      charge_at: params["charge_at"],
      total_count: params["total_count"],
      paid_count: params["paid_count"],
      remaining_count: params["remaining_count"],
      current_start: params["current_start"],
      current_end: params["current_end"]
    }

    Subscriptions.handle_subscription_webhook(razorpay_event_id, subscription_id, subscription_params)
  end

  def handle_order_webhook(razorpay_event_id, payload) do
    params = payload["payload"]["order"]["entity"]
    razorpay_order_id = params["id"]

    order_params = %{
      razorpay_data: payload,
      razorpay_event_id: razorpay_event_id,
      razorpay_order_id: params["id"],
      entity: params["entity"],
      amount: params["amount"],
      amount_paid: params["amount_paid"],
      amount_due: params["amount_due"],
      currency: params["currency"],
      receipt: params["receipt"],
      offer_id: params["offer_id"],
      status: params["status"],
      attempts: params["attempts"],
      notes: params["notes"],
      created_at: params["created_at"]
    }

    Orders.handle_order_webhook(razorpay_event_id, razorpay_order_id, order_params)
  end

  def handle_payment_webhook(razorpay_event_id, payload) do
    params = payload["payload"]["payment"]["entity"]
    razorpay_order_id = params["order_id"]

    payment_params = %{
      razorpay_data: payload,
      razorpay_event_id: razorpay_event_id,
      razorpay_order_id: razorpay_order_id,
      razorpay_payment_id: params["id"],
      entity: params["entity"],
      amount: params["amount"],
      currency: params["currency"],
      status: params["status"],
      invoice_id: params["invoice_id"],
      international: params["international"],
      method: params["method"],
      amount_refunded: params["amount_refunded"],
      refund_status: params["refund_status"],
      captured: params["captured"],
      description: params["description"],
      card_id: params["card_id"],
      bank: params["bank"],
      wallet: params["wallet"],
      vpa: params["vpa"],
      email: params["email"],
      contact: params["contact"],
      notes: params["notes"],
      fee: params["fee"],
      tax: params["tax"],
      error_code: params["error_code"],
      error_description: params["error_description"],
      error_source: params["error_source"],
      error_step: params["error_step"],
      error_reason: params["error_reason"],
      acquirer_data: params["acquirer_data"],
      created_at: params["created_at"]
    }


    Orders.handle_order_webhook(razorpay_event_id, razorpay_order_id, payment_params)
  end

  def handle_invoice_payout_webhook(_razorpay_event_id, payload) do
    params = payload["payload"]["payout"]["entity"]
    razorpay_order_id = params["id"]

    channel = ApplicationHelper.get_slack_channel()
    ApplicationHelper.notify_on_slack(
      "Got Razorpay webhook for razorpay_order_id: #{params["id"]}, razorpay_response:#{Jason.encode!(payload)}",
      channel
    )

    InvoicePayout.handle_payout_webhook(razorpay_order_id)
  end
end
