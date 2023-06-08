defmodule BnApis.Repo.Migrations.AddIsEnabledForCommercialToStories do
  use Ecto.Migration

  def change do
    alter table(:stories) do
      add(:is_enabled_for_commercial, :boolean, default: false)
    end
  end
end
