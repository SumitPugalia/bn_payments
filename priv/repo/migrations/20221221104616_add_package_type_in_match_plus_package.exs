defmodule BnApis.Repo.Migrations.AddPackageTypeInMatchPlusPackage do
  use Ecto.Migration

  def change do
    alter table(:match_plus_packages) do
      add :package_type, :string, default: "owners"
    end
  end
end
