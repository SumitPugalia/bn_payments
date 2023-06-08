defmodule BnApis.Repo.Migrations.AddIndexOnExpiryInRentalPropertyPosts do
  use Ecto.Migration
  @disable_ddl_transaction true
  @disable_migration_lock true

  def change do
    create index("rental_property_posts", [:expires_in], concurrently: true)
  end
end
