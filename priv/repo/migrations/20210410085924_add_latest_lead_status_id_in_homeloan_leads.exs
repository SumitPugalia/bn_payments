defmodule BnApis.Repo.Migrations.AddLatestLeadStatusIdInHomeloanLeads do
  use Ecto.Migration

  def change do
    alter table(:homeloan_leads) do
      add(:latest_lead_status_id, references(:homeloan_lead_statuses))
    end
  end
end
