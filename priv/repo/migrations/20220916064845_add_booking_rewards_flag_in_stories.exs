defmodule BnApis.Repo.Migrations.AddFlagsMapInStories do
  use Ecto.Migration

  def up do
    alter table(:stories) do
      add(:is_booking_reward_enabled, :boolean, default: false)
    end
  end

  def down do
    alter table(:stories) do
      remove(:is_booking_reward_enabled)
    end
  end
end
