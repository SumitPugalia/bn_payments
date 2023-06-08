defmodule BnApis.Repo.Migrations.AddSmsSentToCabBookingRequests do
  use Ecto.Migration

  def change do
    alter table(:cab_booking_requests) do
      add(:sms_sent, :boolean, default: false)
    end
  end
end
