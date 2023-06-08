defmodule BnApis.Repo.Migrations.AddVehicleTypeInCabVehicles do
  use Ecto.Migration

  def change do
    alter table(:cab_vehicles) do
      add(:vehicle_type, :string)
    end
  end
end
