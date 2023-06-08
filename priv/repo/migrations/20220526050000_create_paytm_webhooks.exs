defmodule BnApis.Repo.Migrations.CreatePaytmWebhooks do
  use Ecto.Migration

  def change do
    create table(:paytm_webhooks) do
      add :txn_id, :string
      add :txn_date, :string
      add :txn_amount, :decimal
      add :subs_id, :string
      add :status, :string
      add :resp_msg, :string
      add :resp_code, :string
      add :payment_mode, :string
      add :order_id, :string
      add :mid, :string
      add :gateway_name, :string
      add :currency, :string
      add :checksum_hash, :string
      add :bank_txn_id, :string
      add :bank_name, :string

      timestamps()
    end
  end
end
