defmodule BnApis.Repo.Migrations.CreateResaleClientPosts do
  use Ecto.Migration

  def change do
    create table(:resale_client_posts) do
      add :uuid, :uuid, default: fragment("uuid_generate_v1mc()"), null: false
      add :name, :string
      add :building_ids, {:array, :integer}
      add :max_budget, :integer
      add :min_carpet_area, :integer
      add :min_parking, :integer
      add :notes, :string
      add :configuration_type_ids, {:array, :integer}
      add :floor_type_ids, {:array, :integer}
      add :user_id, references(:credentials, on_delete: :nothing)
      add :assigned_user_id, references(:credentials, on_delete: :nothing)

      timestamps()
    end

    create index(:resale_client_posts, [:user_id])
    create index(:resale_client_posts, [:assigned_user_id])
  end
end
