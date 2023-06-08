defmodule BnApis.Repo.Migrations.CreateResalePropertyPosts do
  use Ecto.Migration

  def change do
    create table(:resale_property_posts) do
      add :uuid, :uuid, default: fragment("uuid_generate_v1mc()"), null: false
      add :price, :integer
      add :carpet_area, :integer
      add :parking, :integer
      add :notes, :string
      add :building_id, references(:buildings, on_delete: :nothing)
      add :configuration_type_id, references(:posts_configuration_types, on_delete: :nothing)
      add :floor_type_id, references(:posts_floor_types, on_delete: :nothing)
      add :user_id, references(:credentials, on_delete: :nothing)
      add :assigned_user_id, references(:credentials, on_delete: :nothing)

      timestamps()
    end

    create index(:resale_property_posts, [:building_id])
    create index(:resale_property_posts, [:configuration_type_id])
    create index(:resale_property_posts, [:floor_type_id])
    create index(:resale_property_posts, [:user_id])
    create index(:resale_property_posts, [:assigned_user_id])
  end
end
