defmodule BnApis.Repo.Migrations.AddMatchPlusPackageIdInOrder do
  use Ecto.Migration

  def change do
    alter table(:orders) do
      add :match_plus_package_id, references(:match_plus_packages, on_delete: :nothing)
    end
  end
end
