defmodule BnApis.Repo.Migrations.IndexOnBrokerIdMatchPlus do
  use Ecto.Migration

  def change do
    create index(:match_plus, [:broker_id])
    create index(:match_plus, [:status_id])
  end
end
