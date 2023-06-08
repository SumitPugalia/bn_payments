defmodule BnApis.Repo.Migrations.AddDefaultPackageInMatchPlusPackage do
  use Ecto.Migration

  def change do
    alter table(:match_plus_packages) do
      add(:is_default, :boolean, default: false)
    end
  end
end
