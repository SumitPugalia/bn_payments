defmodule BnApis.Repo.Migrations.AddFieldDisabledRewardsReasonInStories do
  use Ecto.Migration

  def change do
    alter table(:stories) do
      add(:disabled_rewards_reason, :string)
    end
  end
end
