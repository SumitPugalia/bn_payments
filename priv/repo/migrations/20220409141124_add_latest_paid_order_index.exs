defmodule BnApis.Repo.Migrations.AddLatestPaidOrderIndex do
  use Ecto.Migration

  def change do
    create index(:match_plus, [:latest_paid_order_id])
    create index(:match_plus, [:latest_order_id])
  end
end
