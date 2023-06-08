defmodule BnApis.Repo.Migrations.CreateEmployeesAssignedBrokersCallLogs do
  use Ecto.Migration

  def change do
    create table(:employees_assigned_brokers_call_logs) do
      add :uuid, :uuid, default: fragment("uuid_generate_v1mc()"), null: false

      add :employees_assigned_brokers_id,
          references(:employees_assigned_brokers, on_delete: :nothing)

      timestamps()
    end
  end
end
