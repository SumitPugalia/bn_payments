defmodule BnApis.Repo.Migrations.AddIsUnlockedInRentalMatches do
  use Ecto.Migration

  def change do
    alter table(:rental_matches) do
      add :is_unlocked, :boolean, default: false
    end
  end
end
