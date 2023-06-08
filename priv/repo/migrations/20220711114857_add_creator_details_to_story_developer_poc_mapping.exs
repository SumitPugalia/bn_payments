defmodule BnApis.Repo.Migrations.AddCreatorDetailsToStoryDeveloperPocMapping do
  use Ecto.Migration

  def change do
    alter table(:story_developer_poc_mappings) do
      add :user_id, :integer
      add :user_type, :string
    end
  end
end
