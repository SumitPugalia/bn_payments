defmodule BnApis.Repo.Migrations.CreateStoriesSections do
  use Ecto.Migration

  def change do
    create table(:stories_sections) do
      add :uuid, :uuid, default: fragment("uuid_generate_v1mc()"), null: false
      add :interval, :integer
      add :resource_url, :string
      add :seen_at, :naive_datetime
      add :resource_type_id, references(:stories_section_resource_types, on_delete: :nothing)
      add :story_id, references(:stories, on_delete: :nothing)

      timestamps()
    end

    create index(:stories_sections, [:resource_type_id])
    create index(:stories_sections, [:story_id])
  end
end
