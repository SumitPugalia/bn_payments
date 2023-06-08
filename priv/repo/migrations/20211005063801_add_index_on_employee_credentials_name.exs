defmodule BnApis.Repo.Migrations.AddIndexOnEmployeeCredentialsName do
  use Ecto.Migration

  def up do
    execute(
      "CREATE INDEX pattern_index_employees_credentials_name ON employees_credentials (lower(name) varchar_pattern_ops)"
    )
  end

  def down do
    execute("DROP INDEX pattern_index_employees_credentials_name")
  end
end
