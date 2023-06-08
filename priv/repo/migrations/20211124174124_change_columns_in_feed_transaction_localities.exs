defmodule BnApis.Repo.Migrations.ChangeColumnsInFeedTransactionLocalities do
  use Ecto.Migration

  def change do
    alter table(:feed_transaction_localities) do
      remove :locality_id
      add :city_id, :integer
      add :polygon_uuids, {:array, :string}
    end
  end
end
