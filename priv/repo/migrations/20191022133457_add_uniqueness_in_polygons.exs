defmodule BnApis.Repo.Migrations.AddUniquenessInPolygons do
  use Ecto.Migration
  @disable_ddl_transaction true
  @disable_migration_lock true

  def change do
    create unique_index("polygons", [:name], concurrently: true)
  end
end
