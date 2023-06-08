defmodule BnApis.Repo.Migrations.CreateOrders do
  use Ecto.Migration

  def change do
    create table(:orders) do
      add(:razorpay_order_id, :string, null: false)
      add(:amount, :integer)
      add(:amount_paid, :integer)
      add(:amount_due, :integer)
      add(:created_at, :integer)
      add(:currency, :string)
      add(:receipt, :string)
      add(:status, :string)
      add(:attempts, :integer)

      add(:current_start, :integer)
      add(:current_end, :integer)
      add(:broker_phone_number, :string)
      add(:is_client_side_payment_successful, :boolean)

      add(:broker_id, references(:brokers), null: false)
      add(:match_plus_id, references(:match_plus), null: false)

      timestamps()
    end
  end
end
