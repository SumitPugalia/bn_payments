defmodule BnApis.Repo.Migrations.AddBrokerTypeInBrokers do
  use Ecto.Migration

  def change do
    alter table(:brokers) do
      add :broker_type_id, references(:brokers_roles, on_delete: :nothing)
    end
  end
end
