defmodule BnApis.Repo.Migrations.CreateDuplicateBuildingsTemp do
  use Ecto.Migration

  def change do
    create table(:duplicate_buildings_temp) do
      add :name, :string
      add :count, :integer
      add :hide, :boolean, default: false, null: false

      timestamps()
    end
  end
end
