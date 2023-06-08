defmodule BnApis.Repo.Migrations.AddLatestPaidOrderIdToMatchPlus do
  use Ecto.Migration

  def change do
    alter table(:match_plus) do
      add(:latest_paid_order_id, references(:orders), null: true)
    end
  end
end
