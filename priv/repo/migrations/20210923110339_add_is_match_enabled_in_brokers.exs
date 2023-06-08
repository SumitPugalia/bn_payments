defmodule BnApis.Repo.Migrations.AddIsMatchEnabledInBrokers do
  use Ecto.Migration

  def change do
    alter table(:brokers) do
      add(:is_match_enabled, :bool)
    end
  end
end
