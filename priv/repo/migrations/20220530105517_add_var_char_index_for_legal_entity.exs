defmodule BnApis.Repo.Migrations.AddVarCharIndexForLegalEntity do
  use Ecto.Migration

  def up do
    drop_if_exists index(:legal_entities, [:legal_entity_name])
    drop_if_exists index(:legal_entities, [:state_code])
    drop_if_exists index(:legal_entities, [:pan])
    drop_if_exists index(:legal_entities, [:gst])

    execute(
      "CREATE INDEX pattern_index_legal_entity_name ON legal_entities (lower(legal_entity_name) varchar_pattern_ops)"
    )
  end

  def down do
    drop_if_exists index(:legal_entities, [:legal_entity_name])
    drop_if_exists index(:legal_entities, [:state_code])
    drop_if_exists index(:legal_entities, [:pan])
    drop_if_exists index(:legal_entities, [:gst])

    execute("DROP INDEX pattern_index_legal_entity_name")
  end
end
