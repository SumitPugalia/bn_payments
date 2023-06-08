defmodule BnApis.Repo.Migrations.ChangeCityIdToZoneIdInPolygons do
  use Ecto.Migration

  def change do
    alter table(:polygons) do
      add :zone_id, references(:zones)
    end
  end
end
