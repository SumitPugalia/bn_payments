defmodule BnApis.Repo.Migrations.AddStatusInVehicleDriverOperator do
  use Ecto.Migration

  def change do
    alter table(:cab_operators) do
      add(:is_deleted, :boolean, default: false)
    end

    alter table(:cab_drivers) do
      add(:is_deleted, :boolean, default: false)
    end

    alter table(:cab_vehicles) do
      add(:is_deleted, :boolean, default: false)
    end

    drop_if_exists index(:cab_drivers, [:phone_number])

    drop_if_exists index(:cab_drivers, [:phone_number],
                     where: "is_deleted is null OR is_deleted = false",
                     name: :cab_drivers_unique_constraint_on_not_is_deleted
                   )

    create unique_index(:cab_drivers, [:phone_number],
             where: "is_deleted is null OR is_deleted = false",
             name: :cab_drivers_unique_constraint_on_not_is_deleted
           )

    drop_if_exists index(:cab_vehicles, ["lower(vehicle_number)"],
                     name: :uniq_cab_vehicles_number_idx
                   )

    drop_if_exists index(:cab_vehicles, ["lower(vehicle_number)"],
                     where: "is_deleted is null OR is_deleted = false",
                     name: :cab_vehicles_unique_constraint_on_not_is_deleted
                   )

    create unique_index(:cab_vehicles, ["lower(vehicle_number)"],
             where: "is_deleted is null OR is_deleted = false",
             name: :cab_vehicles_unique_constraint_on_not_is_deleted
           )
  end
end
