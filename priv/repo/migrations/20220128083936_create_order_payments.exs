defmodule BnApis.Repo.Migrations.CreateOrderPayments do
  use Ecto.Migration

  def change do
    create table(:order_payments) do
      add(:order_id, references(:orders), null: false)

      add(:razorpay_order_id, :string, null: false)
      add(:razorpay_payment_id, :string, null: false)
      add(:razorpay_payment_status, :string)
      add(:amount, :integer)
      add(:currency, :string)
      add(:created_at, :integer)
      add(:razorpay_data, :map, default: %{})
      add(:invoice_id, :string)
      add(:international, :boolean)
      add(:method, :string)
      add(:amount_refunded, :integer)
      add(:refund_status, :string)
      add(:captured, :boolean)
      add(:description, :string)
      add(:card_id, :string)
      add(:bank, :string)
      add(:wallet, :string)
      add(:vpa, :string)
      add(:tax, :integer)
      add(:fee, :integer)
      add(:email, :string)
      add(:contact, :string)
      add(:notes, {:array, :string})
      add(:error_code, :string)
      add(:error_description, :string)
      add(:error_source, :string)
      add(:error_step, :string)
      add(:error_reason, :string)

      timestamps()
    end
  end
end
