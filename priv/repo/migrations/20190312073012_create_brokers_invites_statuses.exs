defmodule BnApis.Repo.Migrations.CreateBrokersInvitesStatuses do
  use Ecto.Migration

  def change do
    create table(:brokers_invites_statuses, primary_key: false) do
      add :id, :integer, primary_key: true
      add :name, :string, null: false

      timestamps()
    end

    create unique_index(:brokers_invites_statuses, [:name])
  end
end
