defmodule BnApis.Repo.Migrations.CreateBuildings do
  use Ecto.Migration

  def up do
    create table(:buildings) do
      add :uuid, :uuid, default: fragment("uuid_generate_v1mc()"), null: false
      add :name, :string
      add :address, :map
      add :display_address, :string
      add :remote_id, :integer
      add :locality_id, references(:localities, on_delete: :nothing)
      add :sub_locality_id, references(:sub_localities, on_delete: :nothing)
      add :source_type_id, references(:buildings_source_types, on_delete: :nothing)

      timestamps()
    end

    create index(:buildings, [:locality_id])
    create index(:buildings, [:sub_locality_id])
    create index(:buildings, [:source_type_id])

    execute("SELECT AddGeometryColumn ('buildings','location',4326,'POINT',2)")

    execute("CREATE INDEX buildings_location_index on buildings USING gist (location)")
  end

  def down do
    drop table(:buildings)
  end
end
