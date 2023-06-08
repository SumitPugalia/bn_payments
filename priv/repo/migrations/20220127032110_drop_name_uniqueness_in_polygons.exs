defmodule BnApis.Repo.Migrations.DropNameUniquenessInPolygons do
  use Ecto.Migration

  def change do
    drop_if_exists unique_index(:polygons, [:name])
  end
end
