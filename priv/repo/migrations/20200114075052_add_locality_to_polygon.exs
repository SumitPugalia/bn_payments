defmodule BnApis.Repo.Migrations.AddLocalityToPolygon do
  use Ecto.Migration

  def change do
    alter table(:polygons) do
      add :locality_id, references(:localities, on_delete: :nothing)
    end

    create index(:polygons, [:locality_id])
  end
end
