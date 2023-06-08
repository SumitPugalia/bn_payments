defmodule BnApis.Repo.Migrations.AddIsSlotStartOpenInCabBookingSlots do
  use Ecto.Migration

  def change do
    alter table(:cab_booking_slots) do
      add(:is_slot_start_open, :boolean, default: true)
    end
  end
end
