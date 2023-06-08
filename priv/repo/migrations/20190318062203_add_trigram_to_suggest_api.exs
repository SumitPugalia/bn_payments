defmodule BnApis.Repo.Migrations.AddTrigramToSuggestAPI do
  use Ecto.Migration

  def up do
    execute ~s(CREATE EXTENSION IF NOT EXISTS pg_trgm)
    execute ~s(CREATE INDEX buildings_name_trgm_idx ON buildings USING GIN \(name gin_trgm_ops\))
    execute ~s(CREATE INDEX projects_name_trgm_idx ON projects USING GIN \(name gin_trgm_ops\))
  end

  def down do
    execute ~s(DROP INDEX projects_name_trgm_idx)
    execute ~s(DROP INDEX buildings_name_trgm_idx)
    execute ~s(DROP EXTENSION pg_trgm)
  end
end
