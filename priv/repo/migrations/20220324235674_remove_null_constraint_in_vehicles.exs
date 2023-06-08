defmodule BnApis.Repo.Migrations.RemoveNullConstraintInVehicles do
  use Ecto.Migration

  def change do
    alter table(:cab_vehicles) do
      modify :vehicle_model, :string, null: true, from: :string
      modify :number_of_seats, :integer, null: true, from: :integer
    end
  end
end
