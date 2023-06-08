defmodule BnApis.Repo.Migrations.AddConstraintToBrokerOrganization do
  use Ecto.Migration

  def up do
    drop_if_exists index(:brokers_organizations, [:organization_id, :broker_id, :broker_role_id],
                     name: :brokers_organizations_ids_org_broker_role_index
                   )

    create unique_index(:brokers_organizations, [:organization_id, :broker_id],
             name: :brokers_organizations_ids_org_broker_index
           )

    execute(
      "CREATE UNIQUE INDEX org_broker_active_uniq_index ON brokers_organizations (broker_id) WHERE active = true"
    )
  end

  def down do
    drop_if_exists index(:brokers_organizations, [:organization_id, :broker_id, :broker_role_id],
                     name: :brokers_organizations_ids_org_broker_role_index
                   )

    execute("DROP INDEX org_broker_active_uniq_index")
  end
end
