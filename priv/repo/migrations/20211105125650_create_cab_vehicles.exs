defmodule BnApis.Repo.Migrations.CreateCabVehicles do
  use Ecto.Migration

  def change do
    create table(:cab_vehicles) do
      add :vehicle_model, :string, null: false
      add :vehicle_number, :string, null: false
      add :number_of_seats, :integer, null: false
      add :driver_name, :string, null: false
      add :driver_phone_number, :string, null: false
      add(:cab_operator_id, references(:cab_operators), null: false)
      timestamps()
    end

    create(
      unique_index(:cab_vehicles, ["lower(vehicle_number)"], name: :uniq_cab_vehicles_number_idx)
    )
  end
end
