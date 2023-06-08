defmodule BnApis.Repo.Migrations.AddIndexOnPolygonsName do
  use Ecto.Migration

  def up do
    execute(
      "CREATE INDEX pattern_index_polygons_name ON polygons (lower(name) varchar_pattern_ops)"
    )
  end

  def down do
    execute("DROP INDEX pattern_index_polygons_name")
  end
end
