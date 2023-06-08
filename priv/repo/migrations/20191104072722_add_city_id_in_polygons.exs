defmodule BnApis.Repo.Migrations.AddCityIdInPolygons do
  use Ecto.Migration

  def change do
    alter table(:polygons) do
      add :city_id, :integer
    end
  end
end
