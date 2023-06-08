defmodule BnApis.Repo.Migrations.AddLostFieldsInAssignedBrokers do
  use Ecto.Migration

  def change do
    alter table(:employees_assigned_brokers) do
      add :is_marked_lost, :boolean, default: false
      add :lost_reason, :string
    end
  end
end
