defmodule BnApis.Repo.Migrations.CreateEmployeesAssignedBrokersTable do
  use Ecto.Migration

  def change do
    create table(:employees_assigned_brokers) do
      add :employees_credentials_id, references(:employees_credentials, on_delete: :nothing)
      add :active, :boolean, default: true
      add :broker_id, references(:brokers, on_delete: :nothing)
      add :assigned_by_id, references(:employees_credentials, on_delete: :nothing)

      timestamps()
    end

    create index(:employees_assigned_brokers, [:employees_credentials_id])
  end
end
