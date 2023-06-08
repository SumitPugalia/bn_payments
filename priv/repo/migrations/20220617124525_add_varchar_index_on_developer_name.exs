defmodule BnApis.Repo.Migrations.AddVarcharIndexOnDeveloperName do
  use Ecto.Migration

  def up do
    execute(
      "CREATE INDEX index_on_developers_name ON developers (lower(name) varchar_pattern_ops);"
    )
  end

  def down do
    execute("DROP INDEX index_on_developers_name;")
  end
end
