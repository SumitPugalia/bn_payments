defmodule BnApis.Repo.Migrations.AddRulesInMatchPlusPackages do
  use Ecto.Migration

  def change do
    alter table(:match_plus_packages) do
      add :rules, :jsonb
    end
  end
end
