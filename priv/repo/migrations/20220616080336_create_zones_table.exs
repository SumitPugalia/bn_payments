defmodule BnApis.Repo.Migrations.CreateZonesTable do
  use Ecto.Migration

  def change do
    create table(:zones) do
      add :uuid, :uuid, default: fragment("uuid_generate_v1mc()"), null: false
      add :name, :string
      add :city_id, references(:cities)

      timestamps
    end
  end
end
