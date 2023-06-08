defmodule BnApis.Repo.Migrations.CorrectBrokerTypeReference do
  use Ecto.Migration

  def change do
    alter table(:brokers) do
      remove :broker_type_id
      add :broker_type_id, references(:brokers_types, on_delete: :nothing)
    end
  end
end
