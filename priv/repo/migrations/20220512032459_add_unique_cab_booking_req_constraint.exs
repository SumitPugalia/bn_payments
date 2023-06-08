defmodule BnApis.Repo.Migrations.AddUniqueBookingRequestConstraint do
  use Ecto.Migration

  def up do
    execute(
      "CREATE UNIQUE INDEX booking_req_unique_index ON cab_booking_requests (broker_id, client_name, DATE(pickup_time))"
    )
  end

  def down do
    execute("DROP INDEX booking_req_unique_index")
  end
end
