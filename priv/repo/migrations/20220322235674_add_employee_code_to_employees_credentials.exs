defmodule BnApis.Repo.Migrations.AddEmployeeCodeToEmployeesCredentials do
  use Ecto.Migration

  def change do
    alter table(:employees_credentials) do
      add :employee_code, :string
    end
  end
end
