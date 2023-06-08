defmodule BnApis.Repo.Migrations.AddIndexOnExpiresIn do
  use Ecto.Migration

  def change do
    create index(:rental_client_posts, [:expires_in])
    create index(:resale_client_posts, [:expires_in])
  end
end
