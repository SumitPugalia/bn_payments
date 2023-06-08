defmodule BnApis.Repo.Migrations.AddPriorityStoriesTable do
  use Ecto.Migration

  def change do
    create table(:priority_stories) do
      add :active, :boolean, default: true
      add :story_id, references(:stories, on_delete: :nothing)
      add :city_id, references(:cities, on_delete: :nothing)
      add :priority, :integer

      timestamps()
    end

    create unique_index(:priority_stories, [:city_id, :priority, :active],
             where: "active = true",
             name: :unique_active_priority_in_city_index
           )

    create unique_index(:priority_stories, [:city_id, :story_id, :active],
             where: "active = true",
             name: :unique_active_priority_story_in_city_index
           )
  end
end
