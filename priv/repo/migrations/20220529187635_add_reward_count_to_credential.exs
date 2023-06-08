defmodule BnApis.Repo.Migrations.AddRewardCountToBrokers do
  use Ecto.Migration

  def change do
    alter table(:brokers) do
      add :max_rewards_per_day, :integer
    end
  end
end
