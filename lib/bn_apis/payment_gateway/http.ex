defmodule BnApis.PaymentGateway.HTTP do
  alias BnApis.PaymentGateway.Behaviour
  alias BnApis.Helpers.ApplicationHelper
  alias BnApis.Helpers.ExternalApiHelper

  @razorpay_auth_key ApplicationHelper.get_razorpay_auth_key()
  @razorpay_account_number ApplicationHelper.get_razorpay_account_number()
  @razorpay_payment_url ApplicationHelper.get_razorpay_url()

  @behaviour Behaviour

  @impl Behaviour
  @spec make_payment_via_denarri(String.t(), String.t(), map(), String.t(), String.t() | nil) :: {integer(), map()}
  def make_payment_via_denarri(_contact_id, _fund_account_id, _payment_map, _reference_id, _retry_payout_id) do
    {201, %{}}
  end

  @impl Behaviour
  @spec create_razorpay_payout(String.t(), map(), String.t(), String.t(), String.t() | nil) :: {integer(), map()}
  def create_razorpay_payout(razorpay_fund_account_id, payment_const, reference_id, payout_type, retry_payout_id \\ nil) do
    url = @razorpay_payment_url <> "v1/payouts"

    ExternalApiHelper.perform(
      :post,
      url,
      razorpay_post_body(
        razorpay_fund_account_id,
        payment_const,
        reference_id
      ),
      razorpay_headers_payout(
        reference_id,
        payout_type,
        retry_payout_id,
        razorpay_fund_account_id
      ),
      ssl: [{:versions, [:"tlsv1.2"]}]
    )
  end

  defp razorpay_post_body(razorpay_fund_account_id, payment_const, reference_id) do
    %{
      account_number: @razorpay_account_number,
      fund_account_id: razorpay_fund_account_id,
      amount: payment_const["amount"],
      currency: payment_const["currency"],
      mode: payment_const["mode"],
      purpose: payment_const["purpose"],
      queue_if_low_balance: payment_const["queue_if_low_balance"],
      reference_id: "#{reference_id}"
    }
  end

  defp razorpay_headers_payout(reference_id, payout_type, retry_payout_id, razorpay_fund_account_id) do
    if is_nil(retry_payout_id) do
      [
        {"Authorization", "Basic #{@razorpay_auth_key}"},
        {"X-Payout-Idempotency", "rl#{payout_type}#{reference_id}#{razorpay_fund_account_id || ""}"}
      ]
    else
      [
        {"Authorization", "Basic #{@razorpay_auth_key}"},
        {"X-Payout-Idempotency", "rt#{reference_id}#{razorpay_fund_account_id || ""}"}
      ]
    end
  end
end
