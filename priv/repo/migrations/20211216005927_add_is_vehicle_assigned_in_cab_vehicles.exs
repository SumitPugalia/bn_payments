defmodule BnApis.Repo.Migrations.AddIsVehicleAssignedInCabVehicles do
  use Ecto.Migration

  def change do
    alter table(:cab_vehicles) do
      add(:is_vehicle_assigned, :boolean, default: false)
    end
  end
end
