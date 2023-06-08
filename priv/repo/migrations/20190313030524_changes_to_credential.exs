defmodule BnApis.Repo.Migrations.ChangesToCredential do
  use Ecto.Migration

  def up do
    alter table(:credentials) do
      remove :email
      remove :status_id
      remove :phone_number_verified
      add :active, :boolean, default: false, null: false
      add :organization_id, references(:organizations, on_delete: :nothing)
      add :last_active_at, :naive_datetime
      add :broker_role_id, references(:brokers_roles, on_delete: :nothing)
    end

    # User can have only one active account
    create unique_index(:credentials, [:phone_number],
             where: "active = true",
             name: :cred_active_uniq_index
           )

    create index(:credentials, [:organization_id])
    create index(:credentials, [:broker_role_id])
    # A phone number only belongs to one organization (history can be recovered)
    create unique_index(:credentials, [:organization_id, :phone_number],
             name: :cred_phone_org_unique_index
           )

    drop_if_exists unique_index(:credentials, [:email])
    drop_if_exists unique_index(:credentials, [:phone_number])
    drop_if_exists index(:credentials, [:status_id])
  end

  def down do
    alter table(:credentials) do
      add :email, :string
      add :status_id, :id
      add :phone_number_verified, :boolean, default: false, null: false
      remove :active
      remove :organization_id
      remove :last_active_at
      remove :broker_role_id
    end

    # User can have only one active account
    drop_if_exists unique_index(:credentials, [:phone_number],
                     where: "active = true",
                     name: :cred_active_uniq_index
                   )

    drop_if_exists index(:credentials, [:organization_id])
    drop_if_exists index(:credentials, [:broker_role_id])

    # A phone number only belongs to one organization (history can be recovered)
    drop_if_exists unique_index(:credentials, [:organization_id, :phone_number],
                     name: :cred_phone_org_unique_index
                   )
  end
end
