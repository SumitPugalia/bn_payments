defmodule BnApis.Repo.Migrations.AddLatestStatusInRewardsLeads do
  use Ecto.Migration

  def change do
    alter table(:rewards_leads) do
      add(:latest_status_id, references(:rewards_lead_statuses))
    end
  end
end
