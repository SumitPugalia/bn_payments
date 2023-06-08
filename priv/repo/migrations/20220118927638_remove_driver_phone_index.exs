defmodule BnApis.Repo.Migrations.AddStatusInVehicleDriverOperator do
  use Ecto.Migration

  def change do
    drop_if_exists index(:cab_drivers, [:phone_number])
  end
end
