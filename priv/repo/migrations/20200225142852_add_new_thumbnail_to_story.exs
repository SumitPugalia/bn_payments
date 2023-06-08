defmodule BnApis.Repo.Migrations.AddNewThumbnailToStory do
  use Ecto.Migration

  def change do
    alter table(:stories) do
      add :new_story_thumbnail_image_url, :string
    end
  end
end
