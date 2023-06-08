defmodule BnApis.Repo.Migrations.AddDefaultStoryTierId do
  use Ecto.Migration

  def change do
    alter table(:stories) do
      add(:default_story_tier_id, references(:story_tiers))
    end
  end
end
