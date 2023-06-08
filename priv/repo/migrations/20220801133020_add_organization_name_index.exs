defmodule BnApis.Repo.Migrations.AddOrganizationNameIndex do
  use Ecto.Migration

  def change do
    create index(:organizations, ["(lower(name))"])
  end
end
