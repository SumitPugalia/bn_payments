defmodule BnApis.Repo.Migrations.AddIndexToBuildingName do
  use Ecto.Migration

  def up do
    execute(
      "CREATE INDEX pattern_index_buildings_name ON stories (lower(name) varchar_pattern_ops)"
    )
  end

  def down do
    execute("DROP INDEX pattern_index_buildings_name")
  end
end
