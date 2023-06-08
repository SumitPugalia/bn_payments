defmodule BnApis.PaytmWebhooks.PaytmWebhook do
  use Ecto.Schema
  import Ecto.Changeset

  schema "paytm_webhooks" do
    field :bank_name, :string
    field :bank_txn_id, :string
    field :checksum_hash, :string
    field :currency, :string
    field :gateway_name, :string
    field :cust_id, :string
    field :mid, :string
    field :order_id, :string
    field :payment_mode, :string
    field :resp_code, :string
    field :resp_msg, :string
    field :status, :string
    field :subs_id, :string
    field :txn_amount, :decimal
    field :txn_date, :string
    field :txn_id, :string
    field :masked_account_number, :string
    field :issuing_bank_logo, :string
    field :issuing_bank, :string
    field :ifsc, :string
    field :txn_date_time, :string
    field :merc_unq_ref, :string
    field :total_retry_count, :string
    field :retries_left, :string
    field :last_retry_done_attempted_time, :string
    field :retry_allowed, :string
    field :error_message, :string
    field :error_code, :string

    timestamps()
  end

  @doc false
  def changeset(paytm_webhook, attrs) do
    paytm_webhook
    |> cast(attrs, [
      :bank_name,
      :bank_txn_id,
      :checksum_hash,
      :currency,
      :gateway_name,
      :cust_id,
      :mid,
      :order_id,
      :payment_mode,
      :resp_code,
      :resp_msg,
      :status,
      :subs_id,
      :txn_amount,
      :txn_date,
      :txn_id,
      :masked_account_number,
      :issuing_bank_logo,
      :issuing_bank,
      :ifsc,
      :txn_date_time,
      :merc_unq_ref,
      :total_retry_count,
      :retries_left,
      :last_retry_done_attempted_time,
      :retry_allowed,
      :error_message,
      :error_code
    ])
  end
end
