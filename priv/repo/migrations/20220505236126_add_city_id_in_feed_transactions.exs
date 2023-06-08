defmodule BnApis.Repo.Migrations.AddCityIdInFeedTransactions do
  use Ecto.Migration

  def change do
    alter table(:feed_transactions) do
      add :propstack_city_id, :integer
      add :original_data, :map
    end

    alter table(:feed_transaction_localities) do
      add :propstack_city_id, :integer
    end
  end
end
