defmodule BnApis.Repo.Migrations.AddEmployeeIdInHomeLoanLead do
  use Ecto.Migration

  def change do
    alter table(:homeloan_leads) do
      add(:employee_credentials_id, references(:employees_credentials), null: true)
    end
  end
end
