defmodule BnApis.Repo.Migrations.AddIsUnlockedInResaleMatches do
  use Ecto.Migration

  def change do
    alter table(:resale_matches) do
      add :is_unlocked, :boolean, default: false
    end
  end
end
