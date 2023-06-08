defmodule BnApis.Repo.Migrations.AddActiveStoryTransaction do
  use Ecto.Migration

  def change do
    alter table(:story_transactions) do
      add :active, :boolean, default: true
    end
  end
end
