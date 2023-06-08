defmodule BnApis.Repo.Migrations.AddTrgmToLocality do
  use Ecto.Migration

  def up do
    execute ~s(CREATE EXTENSION IF NOT EXISTS pg_trgm)

    execute ~s(CREATE INDEX localities_name_trgm_idx ON localities USING GIN \(name gin_trgm_ops\))
  end

  def down do
    execute ~s(DROP INDEX localities_name_trgm_idx)
    execute ~s(DROP EXTENSION pg_trgm)
  end
end
