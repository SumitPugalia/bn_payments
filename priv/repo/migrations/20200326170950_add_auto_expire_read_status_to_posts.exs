defmodule BnApis.Repo.Migrations.AddAutoExpireReadStatusToPosts do
  use Ecto.Migration

  def change do
    alter table(:rental_client_posts) do
      add :auto_expired_read, :boolean, default: false
    end

    alter table(:rental_property_posts) do
      add :auto_expired_read, :boolean, default: false
    end

    alter table(:resale_client_posts) do
      add :auto_expired_read, :boolean, default: false
    end

    alter table(:resale_property_posts) do
      add :auto_expired_read, :boolean, default: false
    end
  end
end
