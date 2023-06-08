defmodule BnApis.Repo.Migrations.CreateRentalPropertyPosts do
  use Ecto.Migration

  def change do
    create table(:rental_property_posts) do
      add :uuid, :uuid, default: fragment("uuid_generate_v1mc()"), null: false
      add :rent_expected, :integer
      add :is_bachelor_allowed, :boolean, default: false, null: false
      add :notes, :string
      add :building_id, references(:buildings, on_delete: :nothing)
      add :configuration_type_id, references(:posts_configuration_types, on_delete: :nothing)
      add :furnishing_type_id, references(:posts_furnishing_types, on_delete: :nothing)
      add :user_id, references(:credentials, on_delete: :nothing)
      add :assigned_user_id, references(:credentials, on_delete: :nothing)

      timestamps()
    end

    create index(:rental_property_posts, [:building_id])
    create index(:rental_property_posts, [:configuration_type_id])
    create index(:rental_property_posts, [:furnishing_type_id])
    create index(:rental_property_posts, [:user_id])
    create index(:rental_property_posts, [:assigned_user_id])
  end
end
