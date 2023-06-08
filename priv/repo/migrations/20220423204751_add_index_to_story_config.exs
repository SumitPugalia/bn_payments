defmodule BnApis.Repo.Migrations.AddIndexToStoryConfig do
  use Ecto.Migration

  def change do
    create index(:story_project_configs, [:story_id])
  end
end
