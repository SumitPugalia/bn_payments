defmodule BnApis.Repo.Migrations.CreateStoriesUserFavourites do
  use Ecto.Migration

  def change do
    create table(:stories_user_favourites) do
      add :timestamp, :naive_datetime
      add :credential_id, references(:credentials, on_delete: :nothing)
      add :story_id, references(:stories, on_delete: :nothing)

      timestamps()
    end

    create index(:stories_user_favourites, [:credential_id])
    create index(:stories_user_favourites, [:story_id])

    create unique_index(:stories_user_favourites, [:credential_id, :story_id],
             name: :stories_user_favourites_ids_index
           )
  end
end
