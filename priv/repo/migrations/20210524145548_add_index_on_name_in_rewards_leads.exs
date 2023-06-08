defmodule BnApis.Repo.Migrations.AddIndexOnNameInRewardsLeads do
  use Ecto.Migration

  def up do
    execute(
      "CREATE INDEX index_on_rewards_leads_name ON rewards_leads (lower(name) varchar_pattern_ops);"
    )
  end

  def down do
    execute("DROP INDEX index_on_rewards_leads_name;")
  end
end
