defmodule BnApis.Repo.Migrations.CreateStoriesUserSeens do
  use Ecto.Migration

  def change do
    create table(:stories_user_seens) do
      add :timestamp, :naive_datetime
      add :credential_id, references(:credentials, on_delete: :nothing)
      add :story_id, references(:stories, on_delete: :nothing)
      add :story_section_id, references(:stories_sections, on_delete: :nothing)

      timestamps()
    end

    create index(:stories_user_seens, [:credential_id])
    create index(:stories_user_seens, [:story_id])
    create index(:stories_user_seens, [:story_section_id])

    create unique_index(:stories_user_seens, [:credential_id, :story_id, :story_section_id],
             name: :stories_user_seens_ids_index
           )
  end
end
