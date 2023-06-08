defmodule BnApis.Repo.Migrations.AddIsCapturedInOrders do
  use Ecto.Migration

  def change do
    alter table(:orders) do
      add(:is_captured, :boolean, default: false)
    end
  end
end
