defmodule BnApis.Repo.Migrations.AddHlLeadAllowedToCredentials do
  use Ecto.Migration

  def change do
    alter table(:employees_credentials) do
      add(:hl_lead_allowed, :boolean, default: false)
    end
  end
end
