defmodule BnApis.Repo.Migrations.ChangeNameUniquenessInPolygons do
  use Ecto.Migration

  def change do
    create unique_index(:polygons, [:name, :city_id], name: :polygon_name_city_id_index)
  end
end
