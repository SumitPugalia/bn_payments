defmodule BnApis.Repo.Migrations.CreateStoryDeveloperPocMapping do
  use Ecto.Migration

  def change do
    create table(:story_developer_poc_mappings) do
      add(:story_id, references(:stories), null: false)

      add(:developer_poc_credential_id, references(:developer_poc_credentials), null: false)

      add(:active, :boolean, null: false)
      timestamps()
    end

    create(
      unique_index(
        :story_developer_poc_mappings,
        [:story_id, :developer_poc_credential_id],
        name: :uniq_story_poc_mapping_index
      )
    )
  end
end
