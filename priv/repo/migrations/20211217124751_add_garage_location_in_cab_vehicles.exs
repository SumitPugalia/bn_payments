defmodule BnApis.Repo.Migrations.AddGarageLocationInCabVehicles do
  use Ecto.Migration

  def change do
    alter table(:cab_vehicles) do
      add(:garage_location, :string)
    end
  end
end
