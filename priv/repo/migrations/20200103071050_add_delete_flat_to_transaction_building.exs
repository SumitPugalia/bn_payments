defmodule BnApis.Repo.Migrations.AddDeleteFlatToTransactionBuilding do
  use Ecto.Migration

  def change do
    alter table(:transactions_buildings) do
      add :delete, :boolean, null: false, default: false
    end
  end
end
