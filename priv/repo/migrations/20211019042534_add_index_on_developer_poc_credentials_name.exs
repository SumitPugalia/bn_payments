defmodule BnApis.Repo.Migrations.AddIndexOnDeveloperPocCredentialsName do
  use Ecto.Migration

  def up do
    execute(
      "CREATE INDEX pattern_index_dev_poc_credentials_name ON developer_poc_credentials (lower(name) varchar_pattern_ops)"
    )
  end

  def down do
    execute("DROP INDEX pattern_index_dev_poc_credentials_name")
  end
end
