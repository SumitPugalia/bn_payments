defmodule BnApis.Repo.Migrations.AddClaimClosedToRewardsLead do
  use Ecto.Migration

  def change do
    alter table(:rewards_leads) do
      add(:claim_closed, :boolean, default: false)
    end
  end
end
