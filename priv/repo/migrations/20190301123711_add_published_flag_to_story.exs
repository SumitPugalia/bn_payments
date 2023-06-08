defmodule BnApis.Repo.Migrations.AddPublishedFlagToStory do
  use Ecto.Migration

  def change do
    alter table(:stories) do
      add :published, :boolean, default: false, null: false
    end
  end
end
