defmodule BnApis.Repo.Migrations.AddCityToBookingSlot do
  use Ecto.Migration

  def change do
    alter table(:cab_booking_slots) do
      add(:city_id, references(:cities), null: true)
    end
  end
end
