defmodule BnApis.Repo.Migrations.CreateCabBookingRequests do
  use Ecto.Migration

  def change do
    create table(:cab_booking_requests) do
      add :client_name, :string, null: false
      add :project_ids, {:array, :integer}, null: false, default: []
      add :pickup_time, :naive_datetime, null: false
      add :latitude, :string, null: false
      add :longitude, :string, null: false
      add :address, :string, null: false
      add :no_of_persons, :integer
      add :status_id, :integer, null: false
      add :chauffeur_phone_number, :string
      add :cab_number, :string
      add :chauffeur_name, :string
      add(:broker_id, references(:brokers), null: false)
      timestamps()
    end

    create index("cab_booking_requests", [:pickup_time])
  end
end
