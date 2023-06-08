defmodule BnApis.Repo.Migrations.ChangeFloorTypeInFeedTransactions do
  use Ecto.Migration

  def change do
    alter table(:feed_transactions) do
      modify :floor, :string
    end
  end
end
