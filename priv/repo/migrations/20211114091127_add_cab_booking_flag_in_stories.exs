defmodule BnApis.Repo.Migrations.AddCabBookingFlagInStories do
  use Ecto.Migration

  def change do
    alter table(:stories) do
      add(:is_cab_booking_enabled, :boolean, default: false)
    end
  end
end
