defmodule BnApis.Repo.Migrations.CreateOwnerEmployeeMappingTable do
  use Ecto.Migration

  def change do
    create table(:owners_broker_employee_mappings) do
      add :employees_credentials_id, references(:employees_credentials, on_delete: :nothing)
      add :active, :boolean, default: true
      add :broker_id, references(:brokers, on_delete: :nothing)
      add :assigned_by_id, references(:employees_credentials, on_delete: :nothing)

      timestamps()
    end

    create index(:owners_broker_employee_mappings, [:employees_credentials_id])
    create index(:owners_broker_employee_mappings, [:broker_id])

    create unique_index(
             :owners_broker_employee_mappings,
             [:employees_credentials_id, :broker_id, :active],
             where: "active = true",
             name: :owners_broker_employee_mappings_uniq_index
           )
  end
end
