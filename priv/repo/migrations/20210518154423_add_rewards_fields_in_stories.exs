defmodule BnApis.Repo.Migrations.AddRewardsFieldsInStories do
  use Ecto.Migration

  def change do
    alter table(:stories) do
      add(:is_rewards_enabled, :boolean, default: false)
      add(:total_rewards_amount, :integer, default: 0)
      add(:rewards_bn_poc_id, references(:employees_credentials))
    end
  end
end
