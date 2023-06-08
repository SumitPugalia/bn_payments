defmodule BnApis.Repo.Migrations.AddPolygonsInBrokers do
  use Ecto.Migration

  def change do
    alter table(:brokers) do
      add :polygon_id, references(:polygons, on_delete: :nothing)
    end
  end
end
