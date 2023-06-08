defmodule BnApis.Repo.Migrations.AddManuallyDeactivatedForRewardsToStories do
  use Ecto.Migration

  def change do
    alter table(:stories) do
      add :is_manually_deacticated_for_rewards, :boolean, default: false
    end

    alter table(:story_transactions) do
      add :remark, :string
      add :proof_url, :string
    end
  end
end
