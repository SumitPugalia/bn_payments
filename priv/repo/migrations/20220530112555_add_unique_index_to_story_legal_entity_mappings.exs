defmodule BnApis.Repo.Migrations.AddUniqueIndexToStoryLegalEntityMappings do
  use Ecto.Migration

  def up do
    drop_if_exists index(:story_legal_entity_mappings, [:story_id, :legal_entity_id],
                     name: :unique_story_legal_entity_mapping_index
                   )

    execute(
      "CREATE UNIQUE INDEX unique_stories_legal_entity_mapping_index ON story_legal_entity_mappings (story_id, legal_entity_id) WHERE active = true"
    )
  end

  def down do
    drop_if_exists index(:story_legal_entity_mappings, [:story_id, :legal_entity_id],
                     name: :unique_story_legal_entity_mapping_index
                   )

    execute("DROP INDEX unique_stories_legal_entity_mapping_index")
  end
end
