defmodule BnApis.Repo.Migrations.CreatePolygonsTable do
  use Ecto.Migration

  def change do
    create table(:polygons) do
      add :uuid, :uuid, default: fragment("uuid_generate_v1mc()"), null: false
      add :name, :string
      add :rent_config_expiry, :jsonb
      add :resale_config_expiry, :jsonb
      add :rent_match_parameters, :jsonb
      add :resale_match_parameters, :jsonb

      timestamps
    end
  end
end
