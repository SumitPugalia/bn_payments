defmodule BnApis.Repo.Migrations.CreateSubscriptionInvoices do
  use Ecto.Migration

  def change do
    create table(:subscription_invoices) do
      add(:subscription_id, references(:subscriptions), null: false)
      add(:razorpay_invoice_id, :string, null: false)
      add(:razorpay_invoice_status, :string, null: false)
      add(:razorpay_order_id, :string)
      add(:razorpay_payment_id, :string)
      add(:razorpay_data, :map, default: %{})
      add(:created_at, :integer)
      add(:razorpay_customer_id, :string)
      add(:short_url, :string)
      add(:invoice_number, :string)
      add(:billing_start, :integer)
      add(:billing_end, :integer)
      add(:paid_at, :integer)
      add(:amount, :integer)
      add(:amount_paid, :integer)
      add(:amount_due, :integer)
      add(:date, :integer)
      add(:partial_payment, :boolean)
      add(:tax_amount, :integer)
      add(:taxable_amount, :integer)
      add(:currency, :string)

      timestamps()
    end
  end
end
