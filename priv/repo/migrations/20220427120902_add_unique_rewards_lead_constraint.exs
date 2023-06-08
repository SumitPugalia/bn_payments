defmodule BnApis.Repo.Migrations.AddUniqueRewardsLeadConstraint do
  use Ecto.Migration

  def up do
    execute(
      "CREATE UNIQUE INDEX rewards_lead_unique_index ON rewards_leads (broker_id, story_id, name, DATE(visit_date))"
    )
  end

  def down do
    execute("DROP INDEX rewards_lead_unique_index")
  end
end
