defmodule BnApis.Repo.Migrations.AddTrgmToTransactionBuilding do
  use Ecto.Migration

  def up do
    execute ~s(CREATE EXTENSION IF NOT EXISTS pg_trgm)

    execute ~s(CREATE INDEX transactions_buildings_name_trgm_idx ON transactions_buildings USING GIN \(name gin_trgm_ops\))
  end

  def down do
    execute ~s(DROP INDEX transactions_buildings_name_trgm_idx)
    execute ~s(DROP EXTENSION pg_trgm)
  end
end
