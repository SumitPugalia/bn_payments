defmodule BnApis.Repo.Migrations.AddConfigurationsTypesToRewardsLead do
  use Ecto.Migration

  def change do
    alter table(:rewards_leads) do
      add(:configuration_types, {:array, :integer})
    end
  end
end
