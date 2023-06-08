defmodule BnApis.Repo.Migrations.AddLatestOrderIdInOrders do
  use Ecto.Migration

  def change do
    alter table(:match_plus) do
      add(:latest_order_id, references(:orders))
    end
  end
end
