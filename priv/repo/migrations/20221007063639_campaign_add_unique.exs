defmodule BnApis.Repo.Migrations.CampaignAddUnique do
  use Ecto.Migration

  def change do
    create(
      unique_index(
        :campaign_leads,
        [:campaign_id, :broker_id],
        name: :unique_broker_for_campaign_index
      )
    )

    alter table(:campaign) do
      add :data, :map
    end

    alter table(:stories) do
      add :gate_pass, :string
    end
  end
end
