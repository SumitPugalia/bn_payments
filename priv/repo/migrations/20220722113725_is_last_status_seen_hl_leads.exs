defmodule BnApis.Repo.Migrations.IsLastStatusSeenHlLeads do
  use Ecto.Migration

  def change do
    alter table(:homeloan_leads) do
      add(:is_last_status_seen, :boolean, default: false)
    end
  end
end
