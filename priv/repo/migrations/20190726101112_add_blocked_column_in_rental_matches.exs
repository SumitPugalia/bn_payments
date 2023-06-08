defmodule BnApis.Repo.Migrations.AddBlockedColumnInRentalMatches do
  use Ecto.Migration

  def change do
    alter table(:rental_matches) do
      add :blocked, :boolean, default: false
    end
  end
end
