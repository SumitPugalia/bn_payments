defmodule BnApis.Repo.Migrations.CreatePostsFurnishingTypes do
  use Ecto.Migration

  def change do
    create table(:posts_furnishing_types, primary_key: false) do
      add :id, :integer, primary_key: true
      add :name, :string, null: false

      timestamps()
    end

    create unique_index(:posts_furnishing_types, [:name])
  end
end
