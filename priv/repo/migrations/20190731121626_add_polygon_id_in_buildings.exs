defmodule BnApis.Repo.Migrations.AddPolygonIdInBuildings do
  use Ecto.Migration

  def change do
    alter table(:buildings) do
      add :polygon_id, references(:polygons, on_delete: :nothing)
    end
  end
end
