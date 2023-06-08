defmodule BnApis.Repo.Migrations.AddVehicleIdInCabBookingRequests do
  use Ecto.Migration

  def change do
    alter table(:cab_booking_requests) do
      add(:cab_vehicle_id, references(:cab_vehicles))
      remove :chauffeur_phone_number
      remove :cab_number
      remove :chauffeur_name
    end
  end
end
