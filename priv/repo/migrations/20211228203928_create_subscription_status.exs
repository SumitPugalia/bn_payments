defmodule BnApis.Repo.Migrations.CreateSubscriptionStatus do
  use Ecto.Migration

  def change do
    create table(:subscription_status) do
      add(:status, :string, null: false)
      add(:subscription_id, references(:subscriptions), null: false)
      add(:razorpay_data, :map, default: %{})
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

      timestamps()
    end
  end
end
