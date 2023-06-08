defmodule BnApis.Cabs.VehicleDriverLog do
  use Ecto.Schema
  import Ecto.Changeset
  alias BnApis.Cabs.Driver
  alias BnApis.Cabs.Vehicle
  alias BnApis.Cabs.VehicleDriverLog
  alias BnApis.Repo

  schema "cab_vehicle_cab_driver_logs" do
    belongs_to(:cab_vehicle, Vehicle)
    belongs_to(:cab_driver, Driver)
    timestamps()
  end

  @required [:cab_vehicle_id, :cab_driver_id]
  @optional []

  @doc false
  def changeset(vehicle_driver_log, attrs) do
    vehicle_driver_log
    |> cast(attrs, @required ++ @optional)
    |> validate_required(@required)
    |> foreign_key_constraint(:cab_vehicle_id)
    |> foreign_key_constraint(:cab_driver_id)
  end

  def create!(params) do
    %VehicleDriverLog{}
    |> VehicleDriverLog.changeset(params)
    |> Repo.insert!()
  end

  def update!(vehicle_driver_log, params) do
    vehicle_driver_log
    |> VehicleDriverLog.changeset(params)
    |> Repo.update!()
  end

  def log(vehicle, changeset) do
    if not is_nil(changeset.changes[:cab_driver_id]) do
      params = %{
        "cab_vehicle_id" => vehicle.id,
        "cab_driver_id" => vehicle.cab_driver_id
      }

      %VehicleDriverLog{}
      |> VehicleDriverLog.changeset(params)
      |> Repo.insert!()
    end
  end
end
