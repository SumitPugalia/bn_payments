defmodule BnApis.Repo.Migrations.CreateRentalClientPosts do
  use Ecto.Migration

  def change do
    create table(:rental_client_posts) do
      add :uuid, :uuid, default: fragment("uuid_generate_v1mc()"), null: false
      add :name, :string
      add :max_rent, :integer
      add :is_bachelor, :boolean, default: false, null: false
      add :notes, :string
      add :building_ids, {:array, :integer}
      add :configuration_type_ids, {:array, :integer}
      add :furnishing_type_ids, {:array, :integer}
      add :user_id, references(:credentials, on_delete: :nothing)
      add :assigned_user_id, references(:credentials, on_delete: :nothing)

      timestamps()
    end

    create index(:rental_client_posts, [:user_id])
    create index(:rental_client_posts, [:assigned_user_id])
  end
end
