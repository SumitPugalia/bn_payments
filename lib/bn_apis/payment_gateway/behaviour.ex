defmodule BnApis.PaymentGateway.Behaviour do
  @callback make_payment_via_denarri(String.t(), String.t(), map(), String.t(), String.t()) :: {integer(), map()}
  @callback create_razorpay_payout(String.t(), map(), String.t(), String.t(), String.t() | nil) :: {integer(), map()}
end
