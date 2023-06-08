defmodule BnApis.Repo.Migrations.CreateStoryLegalEntityMapping do
  use Ecto.Migration

  def change do
    create table(:story_legal_entity_mappings) do
      add(:story_id, references(:stories), null: false)
      add(:legal_entity_id, references(:legal_entities), null: false)
      add(:active, :boolean, null: false)
      timestamps()
    end

    create(index(:story_legal_entity_mappings, [:story_id]))
    create(index(:story_legal_entity_mappings, [:legal_entity_id]))

    create(
      unique_index(
        :story_legal_entity_mappings,
        [:story_id, :legal_entity_id],
        name: :unique_story_legal_entity_mapping_index
      )
    )
  end
end
