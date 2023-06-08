defmodule BnApis.Repo.Migrations.AddColumnsToBookingRequest do
  use Ecto.Migration

  def change do
    alter table(:cab_booking_requests) do
      add(:sub_locality, :string)
      add(:locality, :string)
      add(:whatsapp_sent, :boolean, default: false)
      add(:rejection_reason, :string)
    end
  end
end
