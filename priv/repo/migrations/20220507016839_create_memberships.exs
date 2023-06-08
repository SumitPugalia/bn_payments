defmodule BnApis.Repo.Migrations.CreateMemberships do
  use Ecto.Migration

  def change do
    create table(:memberships) do
      add(:bn_order_id, :string, null: false)
      add(:paytm_subscription_id, :string, null: false)
      add(:status, :string, null: false)
      add(:bn_customer_id, :string)
      add(:short_url, :string)
      add(:payment_method, :string)
      add(:created_at, :integer)
      add(:start_at, :integer)
      add(:ended_at, :integer)
      add(:charge_at, :integer)
      add(:current_start, :integer)
      add(:current_end, :integer)
      add(:broker_phone_number, :string)

      add(:broker_id, references(:brokers), null: false)
      add(:match_plus_membership_id, references(:match_plus_memberships), null: false)

      timestamps()
    end
  end
end
