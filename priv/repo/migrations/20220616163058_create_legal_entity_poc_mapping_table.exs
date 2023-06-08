defmodule BnApis.Repo.Migrations.CreateLegalEntityPocMappingTable do
  use Ecto.Migration

  def change do
    create table(:legal_entity_poc_mappings) do
      add(:legal_entity_id, references(:legal_entities), null: false)
      add(:legal_entity_poc_id, references(:legal_entity_pocs), null: false)
      add(:active, :boolean, null: false)
      add(:user_id, :integer, null: false)

      timestamps()
    end

    create(index(:legal_entity_poc_mappings, [:legal_entity_id]))
    create(index(:legal_entity_poc_mappings, [:legal_entity_poc_id]))

    create(
      unique_index(
        :legal_entity_poc_mappings,
        [:legal_entity_id, :legal_entity_poc_id, :active],
        where: "active = true",
        name: :unique_legal_entity_poc_mapping_index
      )
    )
  end
end
