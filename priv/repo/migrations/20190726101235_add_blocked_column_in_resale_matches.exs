defmodule BnApis.Repo.Migrations.AddBlockedColumnInResaleMatches do
  use Ecto.Migration

  def change do
    alter table(:resale_matches) do
      add :blocked, :boolean, default: false
    end
  end
end
