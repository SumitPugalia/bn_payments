defmodule BnApis.Repo.Migrations.AddEmployeeIdInLoanFileStatus do
  use Ecto.Migration

  def change do
    alter table(:loan_file_statuses) do
      add(:employee_credential_id, references(:employees_credentials))
    end
  end
end
