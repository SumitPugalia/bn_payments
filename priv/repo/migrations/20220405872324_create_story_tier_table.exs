defmodule BnApis.Repo.Migrations.CreateStoryTierTable do
  use Ecto.Migration

  def change do
    create table(:story_tiers) do
      add :amount, :float, null: false
      add :name, :string, null: false
      add :is_default, :boolean, default: false

      add(:employee_credential_id, references(:employees_credentials), null: false)
      timestamps()
    end

    create unique_index(:story_tiers, [:amount])

    alter table(:stories) do
      add(:story_tier_id, references(:story_tiers), null: true)
    end

    alter table(:rewards_leads) do
      add(:story_tier_id, references(:story_tiers), null: true)
    end
  end
end
