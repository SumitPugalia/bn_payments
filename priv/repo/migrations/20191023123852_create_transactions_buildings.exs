defmodule BnApis.Repo.Migrations.CreateTransactionsBuildings do
  use Ecto.Migration

  def up do
    create table(:transactions_buildings) do
      add :name, :string
      add :locality, :string
      add :address, :string
      add :plus_code, :string
      add :place_id, :string

      timestamps()
    end

    create index(:transactions_buildings, [:place_id])
    create index(:transactions_buildings, [:plus_code])
    create index(:transactions_buildings, [:name])

    execute("SELECT AddGeometryColumn ('transactions_buildings','location',4326,'POINT',2)")

    execute(
      "CREATE INDEX transactions_buildings_location_index on transactions_buildings USING gist (location)"
    )
  end

  def down do
    drop_if_exists table(:transactions_buildings)
    drop_if_exists index(:transactions_buildings, [:place_id])
    drop_if_exists index(:transactions_buildings, [:plus_code])
    drop_if_exists index(:transactions_buildings, [:name])

    execute ~s(DROP INDEX IF EXISTS transactions_buildings_location_index)
  end
end
