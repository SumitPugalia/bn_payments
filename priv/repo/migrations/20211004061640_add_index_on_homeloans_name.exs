defmodule BnApis.Repo.Migrations.AddIndexOnHomeloansName do
  use Ecto.Migration

  def up do
    execute(
      "CREATE INDEX pattern_index_homeloan_leads_name ON homeloan_leads (lower(name) varchar_pattern_ops)"
    )
  end

  def down do
    execute("DROP INDEX pattern_index_homeloan_leads_name")
  end
end
