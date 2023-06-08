defmodule BnApis.Repo.Migrations.PayoutsForInvoice do
  use Ecto.Migration

  def change do
    create table(:invoice_payouts) do
      add :payout_id, :string
      add :status, :string
      add :account_number, :string
      add :utr, :string
      add :fund_account_id, :string
      #Amount in paisa
      add :amount, :float
      add :created_at, :integer
      add :purpose, :string
      add :mode, :string
      add :reference_id, :string
      add :currency, :string

      add :failure_reason, :string
      add :gateway_name, :string
      add :razorpay_data, :map

      add :invoice_id, references(:invoices)
      add :broker_id, references(:brokers)

      timestamps()
    end
  end
end
