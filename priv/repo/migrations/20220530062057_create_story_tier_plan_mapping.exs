defmodule BnApis.Repo.Migrations.CreateStoryTierPlanMapping do
  use Ecto.Migration

  def change do
    create table(:story_tier_plan_mapping) do
      add :story_id, references(:stories, on_delete: :nothing)
      add :story_tier_id, references(:story_tiers, on_delete: :nothing)
      add :start_date, :naive_datetime
      add :end_date, :naive_datetime
      add :active, :boolean, default: true

      timestamps()
    end
  end
end
