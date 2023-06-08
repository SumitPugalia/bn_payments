defmodule BnApis.Repo.Migrations.CreateSubscriptions do
  use Ecto.Migration

  def change do
    create table(:subscriptions) do
      add(:razorpay_plan_id, :string, null: false)
      add(:razorpay_subscription_id, :string, null: false)
      add(:status, :string, null: false)
      add(:razorpay_customer_id, :string)
      add(:short_url, :string)
      add(:payment_method, :string)
      add(:created_at, :integer)
      add(:start_at, :integer)
      add(:ended_at, :integer)
      add(:charge_at, :integer)
      add(:total_count, :integer)
      add(:paid_count, :integer)
      add(:remaining_count, :integer)
      add(:current_start, :integer)
      add(:current_end, :integer)
      add(:broker_phone_number, :string)

      add(:broker_id, references(:brokers), null: false)
      add(:match_plus_subscription_id, references(:match_plus_subscriptions), null: false)

      timestamps()
    end
  end
end
