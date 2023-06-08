defmodule BnApis.Repo.Migrations.CreateMembershipStatus do
  use Ecto.Migration

  def change do
    create table(:membership_status) do
      add(:status, :string, null: false)
      add(:membership_id, references(:memberships), null: false)
      add(:paytm_data, :map, default: %{})
      add(:bn_customer_id, :string)
      add(:short_url, :string)
      add(:payment_method, :string)
      add(:created_at, :integer)
      add(:current_start, :integer)
      add(:current_end, :integer)

      timestamps()
    end
  end
end
