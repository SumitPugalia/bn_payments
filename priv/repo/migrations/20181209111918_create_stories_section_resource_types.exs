defmodule BnApis.Repo.Migrations.CreateStoriesSectionResourceTypes do
  use Ecto.Migration

  def change do
    create table(:stories_section_resource_types, primary_key: false) do
      add :id, :integer, primary_key: true
      add :name, :string, null: false

      timestamps()
    end

    create unique_index(:stories_section_resource_types, [:name])
  end
end
