defmodule BnApis.Repo.Migrations.CreateOrderStatus do
  use Ecto.Migration

  def change do
    create table(:order_status) do
      add(:razorpay_order_id, :string, null: false)
      add(:amount, :integer)
      add(:amount_paid, :integer)
      add(:amount_due, :integer)
      add(:created_at, :integer)
      add(:currency, :string)
      add(:receipt, :string)
      add(:status, :string)
      add(:attempts, :integer)

      add(:razorpay_data, :map, default: %{})
      add(:razorpay_event_id, :string)

      add(:order_id, references(:orders), null: false)

      timestamps()
    end
  end
end
