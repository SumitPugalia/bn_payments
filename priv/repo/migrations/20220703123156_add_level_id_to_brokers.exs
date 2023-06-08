defmodule BnApis.Repo.Migrations.AddLevelIdToBrokers do
  use Ecto.Migration

  def change do
    alter table(:brokers) do
      add :level_id, :integer, default: 1
    end
  end
end
