defmodule BnApis.Repo.Migrations.CreateIndexOnEmailForDevelopers do
  use Ecto.Migration
  @disable_ddl_transaction true
  @disable_migration_lock true

  def change do
    create unique_index("developers", [:email], where: "email is not null", concurrently: true)
  end
end
