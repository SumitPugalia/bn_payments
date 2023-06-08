defmodule BnApis.Repo.Migrations.AddingMatchPlusPackagesToZones do
  use Ecto.Migration

  def change do
    alter table(:zones) do
      add :match_plus_package_id, references(:match_plus_packages)
    end
  end
end
