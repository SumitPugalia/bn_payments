defmodule BnApis.Repo.Migrations.AddLocalityPlaceIdToTransactionBuilding do
  use Ecto.Migration

  def change do
    alter table(:transactions_buildings) do
      add :locality_id, references(:localities, on_delete: :nothing)
    end

    alter table(:localities) do
      add :google_place_id, :text
      add :display_address, :string
    end

    create unique_index(:localities, [:google_place_id])
    create index(:transactions_buildings, [:locality_id])
  end
end
