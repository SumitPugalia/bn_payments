defmodule BnApis.Repo.Migrations.AddIndexOnStories do
  use Ecto.Migration

  def change do
    create index(:stories, [:is_rewards_enabled])
    create index(:stories, [:is_cab_booking_enabled])
  end
end
