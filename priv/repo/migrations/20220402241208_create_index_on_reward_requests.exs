defmodule BnApis.Repo.Migrations.CreateIndexOnRewardRequests do
  use Ecto.Migration

  def change do
    create index(:rewards_leads, [:broker_id])
    create index(:rewards_leads, [:latest_status_id])
    create index(:rewards_leads, [:story_id])
  end
end
