defmodule BnApis.Repo.Migrations.CreateBuildingsSourceTypes do
  use Ecto.Migration

  def change do
    create table(:buildings_source_types, primary_key: false) do
      add :id, :integer, primary_key: true
      add :name, :string, null: false

      timestamps()
    end

    create unique_index(:buildings_source_types, [:name])
  end
end
