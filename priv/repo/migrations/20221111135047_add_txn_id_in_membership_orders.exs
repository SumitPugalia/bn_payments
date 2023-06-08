defmodule BnApis.Repo.Migrations.AddTxnIdInMembershipOrders do
  use Ecto.Migration

  def change do
    alter table(:membership_orders) do
      add(:txn_id, :string)
    end
  end
end
