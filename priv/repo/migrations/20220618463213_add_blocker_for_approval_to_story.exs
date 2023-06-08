defmodule BnApis.Repo.Migrations.AddBlockerForApprovalForStory do
  use Ecto.Migration

  def change do
    alter table(:stories) do
      add :blocked_for_reward_approval, :boolean, default: false
    end
  end
end
