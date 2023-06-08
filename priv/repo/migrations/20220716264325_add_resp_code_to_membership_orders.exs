defmodule BnApis.Repo.Migrations.AddRespCodeToMembershipOrders do
  use Ecto.Migration

  def change do
    alter table(:membership_orders) do
      add(:resp_code, :string)
    end
  end
end
