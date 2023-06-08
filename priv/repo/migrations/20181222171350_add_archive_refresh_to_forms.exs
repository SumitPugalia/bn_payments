defmodule BnApis.Repo.Migrations.AddArchiveRefreshToForms do
  use Ecto.Migration

  def change do
    # rental_property_posts
    alter table(:rental_property_posts) do
      add :archived, :boolean, default: false, null: false
      add :expires_in, :naive_datetime
      add :archived_by_id, references(:credentials, on_delete: :nothing)
      add :refreshed_by_id, references(:credentials, on_delete: :nothing)
    end

    create index(:rental_property_posts, [:archived_by_id])
    create index(:rental_property_posts, [:refreshed_by_id])

    # rental_client_posts
    alter table(:rental_client_posts) do
      add :archived, :boolean, default: false, null: false
      add :expires_in, :naive_datetime
      add :archived_by_id, references(:credentials, on_delete: :nothing)
      add :refreshed_by_id, references(:credentials, on_delete: :nothing)
    end

    create index(:rental_client_posts, [:archived_by_id])
    create index(:rental_client_posts, [:refreshed_by_id])

    # resale_property_posts
    alter table(:resale_property_posts) do
      add :archived, :boolean, default: false, null: false
      add :expires_in, :naive_datetime
      add :archived_by_id, references(:credentials, on_delete: :nothing)
      add :refreshed_by_id, references(:credentials, on_delete: :nothing)
    end

    create index(:resale_property_posts, [:archived_by_id])
    create index(:resale_property_posts, [:refreshed_by_id])

    # resale_client_posts
    alter table(:resale_client_posts) do
      add :archived, :boolean, default: false, null: false
      add :expires_in, :naive_datetime
      add :archived_by_id, references(:credentials, on_delete: :nothing)
      add :refreshed_by_id, references(:credentials, on_delete: :nothing)
    end

    create index(:resale_client_posts, [:archived_by_id])
    create index(:resale_client_posts, [:refreshed_by_id])
  end
end
