defmodule BnApis.Repo.Migrations.CreateStoryProjectConfigs do
  use Ecto.Migration

  def change do
    create table(:story_project_configs) do
      add(:uuid, :uuid, default: fragment("uuid_generate_v1mc()"), null: false)
      add(:story_id, references(:stories), null: false)
      add(:carpet_area, :integer, null: false)
      add(:starting_price, :integer, null: false)
      add(:active, :boolean, null: false, default: true)

      add(:configuration_type_id, references(:posts_configuration_types, on_delete: :nothing),
        null: false
      )

      timestamps()
    end

    create index(:story_project_configs, [:configuration_type_id])
  end
end
