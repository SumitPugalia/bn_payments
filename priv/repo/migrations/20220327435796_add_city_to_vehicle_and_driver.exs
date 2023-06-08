defmodule BnApis.Repo.Migrations.AddCityToVehicleAndDriver do
  use Ecto.Migration

  def change do
    alter table(:cab_vehicles) do
      add(:city_id, references(:cities), null: true)
    end

    alter table(:cab_drivers) do
      add(:city_id, references(:cities), null: true)
    end

    alter table(:cab_booking_requests) do
      add(:city_id, references(:cities), null: true)
    end
  end
end
