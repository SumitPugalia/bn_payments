defmodule BnApis.Repo.Migrations.CreateBrokersUniverse do
  use Ecto.Migration

  def change do
    create table(:brokers_universe) do
      add :uuid, :uuid, default: fragment("uuid_generate_v1mc()"), null: false
      add :name, :string
      add :phone_number, :string
      add :organization_name, :string
      add :locality, :string

      timestamps()
    end
  end
end
