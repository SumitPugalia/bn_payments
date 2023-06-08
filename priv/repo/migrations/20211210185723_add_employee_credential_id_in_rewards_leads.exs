defmodule BnApis.Repo.Migrations.AddEmployeeCredentialIdInRewardsLeads do
  use Ecto.Migration

  def change do
    alter table(:rewards_leads) do
      add(:employee_credential_id, references(:employees_credentials))
    end
  end
end
