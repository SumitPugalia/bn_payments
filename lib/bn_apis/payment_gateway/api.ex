defmodule BnApis.PaymentGateway.API do
  @moduledoc """
  API module for sending and receiving payment
  """
  alias BnApis.PaymentGateway.HTTP

  @spec make_payment_via_denarri(String.t(), String.t(), map(), String.t(), String.t()) :: {integer(), map()}
  def make_payment_via_denarri(contact_id, fund_account_id, payment_map, reference_id, retry_payout_id) do
    config().make_payment_via_denarri(contact_id, fund_account_id, payment_map, reference_id, retry_payout_id)
  end

  @spec create_razorpay_payout(String.t(), map(), String.t(), String.t(), String.t() | nil) :: {integer(), map()}
  def create_razorpay_payout(razorpay_fund_account_id, payment_const, reference_id, payout_type, retry_payout_id \\ nil) do
    config().create_razorpay_payout(razorpay_fund_account_id, payment_const, reference_id, payout_type, retry_payout_id)
  end

  defp config() do
    :bn_apis
    |> Application.get_env(__MODULE__, [])
    |> Keyword.get(:payment_gateway_module, HTTP)
  end
end
