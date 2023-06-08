defmodule BnApis.Repo.Migrations.CreateWhitelistedBrokersInfo do
  use Ecto.Migration

  def change do
    create table(:whitelisted_brokers_info) do
      add :phone_number, :string
      add :broker_name, :string
      add :organization_name, :string
      add :firm_address, :string
      add :polygon_uuid, :string
      add :place_id, :string
      add :created_by_id, references(:employees_credentials, on_delete: :nothing)

      timestamps()
    end
  end
end
