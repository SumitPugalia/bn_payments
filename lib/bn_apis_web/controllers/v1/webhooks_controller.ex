defmodule BnApisWeb.V1.WebhooksController do
  use BnApisWeb, :controller

  alias BnApis.Helpers.PaytmMembershipHelper
  alias BnApis.Helpers.RazorpayWebhookHelper
  alias BnApis.Helpers.WebhookHelper
  alias BnApis.Posts.RawPosts
  alias BnApis.Helpers.Utils

  action_fallback(BnApisWeb.FallbackController)

  def generic_razorpay_webhook(conn, params) do
    razorpay_event_id = conn |> get_req_header("x-razorpay-event-id") |> List.first()
    RazorpayWebhookHelper.handle_razorpay_webhook(razorpay_event_id, params)
    conn |> put_status(:ok) |> json(%{})
  end

  def paytm_webhook(conn, params) do
    PaytmMembershipHelper.handle_subscription_webhook(params)
    conn |> put_status(:ok) |> json(%{})
  end

  def lead_webhook(conn, params) do
    WebhookHelper.handle_lead_webhook(params)
    conn |> put_status(:ok) |> json(%{})
  end

  def raw_lead_fb_webhook(conn, params) do
    webhook_bot_emp_cred = WebhookHelper.get_webhook_bot_employee_credential()
    user_map = Utils.get_user_map_with_employee_cred(webhook_bot_emp_cred.id)
    RawPosts.handle_fb_webhook(user_map, params)
    conn |> put_status(:ok) |> json(%{})
  end

  def lead_propcatalyst_webhook(conn, params) do
    WebhookHelper.handle_lead_propcatalyst_webhook(params)
    conn |> put_status(:ok) |> json(%{})
  end
end
