defmodule BnApis.Repo.Migrations.AddIndexOnExpiryInResalePropertyPosts do
  use Ecto.Migration
  @disable_ddl_transaction true
  @disable_migration_lock true

  def change do
    create index("resale_property_posts", [:expires_in], concurrently: true)
  end
end
