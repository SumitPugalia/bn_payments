defmodule BnApis.Repo.Migrations.AddIsConflictInRewardsLeads do
  use Ecto.Migration

  def change do
    alter table(:rewards_leads) do
      add(:is_conflict, :boolean, default: false)
    end
  end
end
