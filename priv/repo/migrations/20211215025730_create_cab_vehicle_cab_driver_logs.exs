defmodule BnApis.Repo.Migrations.CreateCabVehicleCabDriverMappings do
  use Ecto.Migration

  def change do
    create table(:cab_vehicle_cab_driver_logs) do
      add(:cab_vehicle_id, references(:cab_vehicles), null: false)
      add(:cab_driver_id, references(:cab_drivers), null: false)
      timestamps()
    end
  end
end
