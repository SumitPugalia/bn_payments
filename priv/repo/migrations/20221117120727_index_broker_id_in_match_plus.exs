defmodule BnApis.Repo.Migrations.IndexBrokerIdInMatchPlus do
  use Ecto.Migration

  def change do
    drop index(:match_plus, [:broker_id])
    create unique_index(:match_plus, [:broker_id])
  end
end
