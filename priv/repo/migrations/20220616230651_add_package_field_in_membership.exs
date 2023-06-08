defmodule BnApis.Repo.Migrations.AddPackageFieldInMembership do
  use Ecto.Migration

  def change do
    alter table(:memberships) do
      add :match_plus_package_id, references(:match_plus_packages, on_delete: :nothing),
        null: true
    end
  end
end
