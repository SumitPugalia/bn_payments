defmodule BnApis.Repo.Migrations.CreateCabBookingRequestLogs do
  use Ecto.Migration

  def change do
    create table(:cab_booking_request_logs) do
      add(:cab_booking_request_id, references(:cab_booking_requests), null: false)
      add(:user_id, :integer)
      add(:user_type, :string)
      add(:changes, :jsonb)
      timestamps()
    end
  end
end
