defmodule BnApis.Repo.Migrations.AddCabDriverIdInCabVehicles do
  use Ecto.Migration

  def change do
    alter table(:cab_vehicles) do
      add(:cab_driver_id, references(:cab_drivers), null: false)
      remove :driver_name
      remove :driver_phone_number
    end
  end
end
