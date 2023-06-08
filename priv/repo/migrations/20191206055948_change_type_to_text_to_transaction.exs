defmodule BnApis.Repo.Migrations.ChangeTypeToTextToTransaction do
  use Ecto.Migration

  def change do
    alter table(:transactions_buildings) do
      modify :address, :text
    end
  end
end
