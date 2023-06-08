defmodule BnApis.Repo.Migrations.AddLocationMandatoryForRewardsFlagInBrokers do
  use Ecto.Migration

  def change do
    alter table(:brokers) do
      add(:is_location_mandatory_for_rewards, :boolean, default: false)
    end
  end
end
