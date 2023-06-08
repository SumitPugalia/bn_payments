defmodule BnApis.Repo.Migrations.AddRefreshedAtInPosts do
  use Ecto.Migration

  def change do
    alter table(:resale_property_posts) do
      add :last_refreshed_at, :naive_datetime
    end

    alter table(:rental_property_posts) do
      add :last_refreshed_at, :naive_datetime
    end
  end
end
