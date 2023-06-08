defmodule BnApis.Repo.Migrations.CreateBrokersOrganizations do
  use Ecto.Migration

  def change do
    create table(:brokers_organizations) do
      add :active, :boolean, null: false, default: true
      add :last_active_at, :naive_datetime
      add :organization_id, references(:organizations, on_delete: :nothing)
      add :broker_id, references(:brokers, on_delete: :nothing)
      add :broker_role_id, references(:brokers_roles, on_delete: :nothing)

      timestamps()
    end

    create index(:brokers_organizations, [:organization_id])
    create index(:brokers_organizations, [:broker_id])
    create index(:brokers_organizations, [:broker_role_id])

    create unique_index(:brokers_organizations, [:organization_id, :broker_id, :broker_role_id],
             name: :brokers_organizations_ids_org_broker_role_index
           )
  end
end
