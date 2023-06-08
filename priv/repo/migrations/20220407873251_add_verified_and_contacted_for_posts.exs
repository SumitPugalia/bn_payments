defmodule BnApis.Repo.Migrations.AddVerifiedAndContactedFromBackend do
  use Ecto.Migration

  def change do
    alter table(:resale_property_posts) do
      add :is_verified, :boolean, default: false
    end

    alter table(:rental_property_posts) do
      add :is_verified, :boolean, default: false
    end

    create table(:contacted_rental_property_posts) do
      add :post_id, references(:rental_property_posts, on_delete: :nothing)
      add :user_id, references(:brokers, on_delete: :nothing)
      add :count, :integer

      timestamps()
    end

    create index(:contacted_rental_property_posts, [:post_id])
    create index(:contacted_rental_property_posts, [:user_id])

    create table(:contacted_resale_property_posts) do
      add :post_id, references(:resale_property_posts, on_delete: :nothing)
      add :user_id, references(:brokers, on_delete: :nothing)
      add :count, :integer

      timestamps()
    end

    create index(:contacted_resale_property_posts, [:post_id])
    create index(:contacted_resale_property_posts, [:user_id])
  end
end
