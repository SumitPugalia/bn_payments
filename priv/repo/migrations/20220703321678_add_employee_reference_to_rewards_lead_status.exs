defmodule BnApis.Repo.Migrations.AddEmployeeReferenceToRewardsLeadStatus do
  use Ecto.Migration

  def change do
    alter table(:rewards_lead_statuses) do
      add :employee_credential_id, references(:employees_credentials)
    end
  end
end
