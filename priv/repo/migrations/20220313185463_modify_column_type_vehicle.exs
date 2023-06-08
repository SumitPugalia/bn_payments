defmodule BnApis.Repo.Migrations.ModifyColumnTypeVehicle do
  use Ecto.Migration

  def change do
    drop constraint(:cab_vehicles, "cab_vehicles_cab_driver_id_fkey")

    alter table(:cab_vehicles) do
      modify :cab_driver_id, references(:cab_drivers),
        null: true,
        from: [references(:cab_drivers), null: false]
    end
  end
end
