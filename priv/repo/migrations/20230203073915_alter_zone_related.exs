defmodule BnApis.Repo.Migrations.AlterZoneRelated do
  use Ecto.Migration

  def change do
    alter table(:polygons) do
      add :is_active, :boolean, default: true
    end

    alter table(:zones) do
      add :is_active, :boolean, default: true
    end
  end
end
