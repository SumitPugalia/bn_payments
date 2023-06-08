defmodule BnApis.Repo.Migrations.CreateCabBookingSlots do
  use Ecto.Migration

  def change do
    create table(:cab_booking_slots) do
      add :slot_date, :naive_datetime, null: false
      add :start_date_time, :naive_datetime, null: false
      add :end_date_time, :naive_datetime, null: false
      add :user_id, :integer, null: false
      timestamps()
    end
  end
end
