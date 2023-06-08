defmodule BnApis.Repo.Migrations.CreateBrokersInvites do
  use Ecto.Migration

  def up do
    create table(:brokers_invites) do
      add :uuid, :uuid, default: fragment("uuid_generate_v1mc()"), null: false
      add :phone_number, :string, null: false
      add :broker_role_id, :integer
      add :broker_name, :string
      add :invite_status_id, references(:brokers_invites_statuses, on_delete: :nothing)
      add :invited_by_id, references(:credentials, on_delete: :nothing)

      timestamps()
    end

    create index(:brokers_invites, [:invited_by_id])
    create index(:brokers_invites, [:phone_number])
    create index(:brokers_invites, [:invite_status_id])

    create unique_index(:brokers_invites, [:invited_by_id, :phone_number],
             where: "invite_status_id = 1",
             name: :invited_by_to_phone_number_uniq_index
           )
  end

  def down do
    drop_if_exists table(:brokers_invites)
    drop_if_exists index(:brokers_invites, [:invited_by_id])
    drop_if_exists index(:brokers_invites, [:phone_number])
    drop_if_exists index(:brokers_invites, [:invite_status_id])

    drop_if_exists unique_index(:brokers_invites, [:invited_by_id, :phone_number],
                     where: "invite_status_id = 1",
                     name: :invited_by_to_phone_number_uniq_index
                   )
  end
end
