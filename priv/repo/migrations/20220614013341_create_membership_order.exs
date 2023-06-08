defmodule BnApis.Repo.Migrations.CreateMembershipOrder do
  use Ecto.Migration

  def change do
    create table(:membership_orders) do
      add(:order_id, :string, null: false)
      add(:order_status, :string)
      add(:order_amount, :string)
      add(:order_creation_date, :integer)
      add(:response_message, :string)
      add(:membership_id, references(:memberships), null: false)

      timestamps()
    end
  end
end
