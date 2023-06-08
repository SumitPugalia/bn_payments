defmodule BnApis.Repo.Migrations.CreateSubLocalities do
  use Ecto.Migration

  def up do
    create table(:sub_localities) do
      add :uuid, :uuid, default: fragment("uuid_generate_v1mc()"), null: false
      add :name, :string

      timestamps()
    end

    # Add a field `center` with type `geometry(Point,4326)`.
    # This can store a "standard GPS" (epsg4326) coordinate pair {longitude,latitude}.
    execute("SELECT AddGeometryColumn ('sub_localities','center',4326,'POINT',2)")

    # TODO: srid 3785 - for polygon and then transform it to 4326
    execute("SELECT AddGeometryColumn ('sub_localities','polygon',4326,'POLYGON',2)")

    execute("CREATE INDEX sub_localities_center_index on sub_localities USING gist (center)")
  end

  def down do
    drop table(:sub_localities)
  end
end
