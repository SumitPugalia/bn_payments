defmodule BnApis.Repo.Migrations.AddSlotTimingsToBookingSlot do
  use Ecto.Migration

  def change do
    alter table(:cab_booking_slots) do
      add :booking_start_time, :naive_datetime
      add :booking_end_time, :naive_datetime
    end
  end
end
