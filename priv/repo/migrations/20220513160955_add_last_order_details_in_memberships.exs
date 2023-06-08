defmodule BnApis.Repo.Migrations.AddLastOrderDetailsInMemberships do
  use Ecto.Migration

  def change do
    alter table(:memberships) do
      add(:last_order_id, :string)
      add(:last_order_status, :string)
      add(:last_order_creation_date, :integer)
      add(:last_order_amount, :string)
    end
  end
end
