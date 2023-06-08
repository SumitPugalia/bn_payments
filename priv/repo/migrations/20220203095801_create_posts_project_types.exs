defmodule BnApis.Repo.Migrations.CreatePostsProjectTypes do
  use Ecto.Migration

  def change do
    create table(:posts_project_types, primary_key: false) do
      add :id, :integer, primary_key: true
      add :name, :string, null: false

      timestamps()
    end

    create unique_index(:posts_project_types, [:name])
  end
end
