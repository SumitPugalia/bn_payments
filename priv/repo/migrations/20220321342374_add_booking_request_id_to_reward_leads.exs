defmodule BnApis.Repo.Migrations.AddBookingRequestIdToRewardLeads do
  use Ecto.Migration

  def change do
    alter table(:rewards_leads) do
      add(:cab_booking_requests_id, references(:cab_booking_requests), null: true)
    end
  end
end
