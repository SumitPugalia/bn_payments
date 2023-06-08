defmodule BnApis.Repo.Migrations.AddChannelUrlAssignedBrokerManager do
  use Ecto.Migration

  def change do
    alter table(:employees_assigned_brokers) do
      add :channel_url, :string
    end
  end
end
