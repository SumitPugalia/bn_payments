defmodule BnApis.Repo.Migrations.AddNewColsInStories do
  use Ecto.Migration

  def change do
    alter table(:stories) do
      add :latitude, :string
      add :longitude, :string
      add :marketing_kit_url, :string
      add :project_type_id, references(:posts_project_types, on_delete: :nothing)
    end

    create index(:stories, [:project_type_id])
  end
end
