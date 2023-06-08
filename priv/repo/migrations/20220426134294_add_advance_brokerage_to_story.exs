defmodule BnApis.Repo.Migrations.AddAdvanceBrokerageToStory do
  use Ecto.Migration

  def change do
    alter table(:stories) do
      add(:is_advance_brokerage_enabled, :boolean, default: false)
    end

    create index(:stories, [:is_advance_brokerage_enabled])
  end
end
