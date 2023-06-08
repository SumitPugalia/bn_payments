defmodule BnApis.Cabs.Vehicle do
  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query
  alias BnApis.Cabs.Operator
  alias BnApis.Cabs.Driver
  alias BnApis.Cabs.Vehicle
  alias BnApis.Cabs.Status
  alias BnApis.Cabs.VehicleDriverLog
  alias BnApis.Cabs.BookingRequest
  alias BnApis.Repo
  alias BnApis.Places.City

  schema "cab_vehicles" do
    field :vehicle_model, :string
    field :vehicle_number, :string
    field :vehicle_type, :string
    field :garage_location, :string
    field :number_of_seats, :integer
    field :region, :string
    field :is_blacklisted, :boolean, default: false
    field :is_vehicle_assigned, :boolean, default: false
    field :is_deleted, :boolean, default: false
    field :is_available_for_rerouting, :boolean, default: false
    belongs_to(:cab_operator, Operator)
    belongs_to(:cab_driver, Driver)
    belongs_to(:city, City)
    timestamps()
  end

  # @supported_vehicle_types ["Hatchback", "Sedan", "SUV"]

  @required [:vehicle_number, :cab_operator_id, :city_id]
  @optional [
    :is_vehicle_assigned,
    :garage_location,
    :region,
    :is_blacklisted,
    :is_deleted,
    :cab_driver_id,
    :vehicle_model,
    :vehicle_type,
    :number_of_seats,
    :is_available_for_rerouting
  ]

  @doc false
  def changeset(vehicle, attrs) do
    vehicle
    |> cast(attrs, @required ++ @optional)
    |> validate_required(@required)
    |> unique_constraint(:vehicle_number, name: :cab_vehicles_unique_constraint_on_not_is_deleted)
    |> foreign_key_constraint(:cab_operator_id)
    |> validate_driver_assigned()
    |> validate_driver_city()
  end

  def create!(params) do
    ch = %Vehicle{} |> Vehicle.changeset(params)
    vehicle = ch |> Repo.insert!()
    VehicleDriverLog.log(vehicle, ch)
    vehicle
  end

  def update!(vehicle, params) do
    ch = vehicle |> Vehicle.changeset(params)
    vehicle = ch |> Repo.update!()
    VehicleDriverLog.log(vehicle, ch)
    vehicle
  end

  def assign(cab_vehicle_id, is_vehicle_assigned, is_available_for_rerouting \\ false) do
    Vehicle
    |> Repo.get_by(id: cab_vehicle_id)
    |> Vehicle.update!(%{
      "is_vehicle_assigned" => is_vehicle_assigned,
      "is_available_for_rerouting" => is_available_for_rerouting and is_vehicle_assigned == false
    })
  end

  def check_vehicle(vehicle_number) do
    Vehicle
    |> where([v], (is_nil(v.is_deleted) or v.is_deleted == false) and v.vehicle_number == ^vehicle_number)
    |> Repo.one()
  end

  def get_vehicle_data(nil) do
    %{}
  end

  def get_vehicle_data(params) do
    vehicle = Repo.get(Vehicle, params["id"])
    Vehicle.get_data(vehicle, true, true)
  end

  def get_data(nil) do
    %{}
  end

  def get_data(nil, nil) do
    %{}
  end

  def get_data(vehicle, send_booking_data \\ nil, all_bookings \\ nil) do
    vehicle = vehicle |> Repo.preload([:cab_operator, :cab_driver, :city])

    bookings =
      if not is_nil(send_booking_data),
        do:
          BookingRequest
          |> where([br], br.cab_vehicle_id == ^vehicle.id)
          |> order_by([br], asc: br.pickup_time)
          |> Repo.all(),
        else: []

    latest_booking_data = bookings |> List.last()

    booking = bookings |> Enum.filter(fn br -> br.status_id == Status.get_status_id("driver_assigned") end) |> List.last()

    all_bookings_data =
      if not is_nil(all_bookings) and length(bookings) > 0 do
        bookings
        |> Enum.map(fn br ->
          %{
            "id" => br.id,
            "client_name" => br.client_name,
            "pickup_time" => br.pickup_time,
            "latitude" => br.latitude,
            "longitude" => br.longitude,
            "sms_sent" => br.sms_sent,
            "address" => br.address,
            "created_at" => br.inserted_at,
            "updated_at" => br.updated_at
          }
        end)
      else
        []
      end

    latest_booking =
      if not is_nil(latest_booking_data) do
        %{
          "id" => latest_booking_data.id,
          "client_name" => latest_booking_data.client_name,
          "pickup_time" => latest_booking_data.pickup_time,
          "latitude" => latest_booking_data.latitude,
          "longitude" => latest_booking_data.longitude,
          "sms_sent" => latest_booking_data.sms_sent,
          "address" => latest_booking_data.address,
          "created_at" => latest_booking_data.inserted_at,
          "updated_at" => latest_booking_data.updated_at
        }
      else
        %{}
      end

    booking_data =
      if not is_nil(booking) do
        %{
          "id" => booking.id,
          "client_name" => booking.client_name,
          "pickup_time" => booking.pickup_time,
          "latitude" => booking.latitude,
          "longitude" => booking.longitude,
          "sms_sent" => booking.sms_sent,
          "address" => booking.address,
          "created_at" => booking.inserted_at,
          "updated_at" => booking.updated_at
        }
      else
        %{}
      end

    %{
      "id" => vehicle.id,
      "vehicle_model" => vehicle.vehicle_model,
      "vehicle_number" => vehicle.vehicle_number,
      "vehicle_type" => vehicle.vehicle_type,
      "garage_location" => vehicle.garage_location,
      "is_blacklisted" => vehicle.is_blacklisted,
      "region" => vehicle.region,
      "number_of_seats" => vehicle.number_of_seats,
      "is_vehicle_assigned" => vehicle.is_vehicle_assigned,
      "operator" => Operator.get_data(vehicle.cab_operator),
      "driver" => Driver.get_data(vehicle.cab_driver),
      "created_at" => vehicle.inserted_at,
      "is_deleted" => vehicle.is_deleted,
      "booking_data" => booking_data,
      "updated_at" => vehicle.updated_at,
      "city" => vehicle.city.name,
      "city_id" => vehicle.city.id,
      "all_bookings_data" => all_bookings_data,
      "latest_booking" => latest_booking
    }
  end

  def get_vehicles_list(params) do
    query = params["q"]
    page_no = (params["p"] || "1") |> String.to_integer()
    limit = 100
    offset = (page_no - 1) * limit
    hide_blacklisted = params["hide_blacklisted"]

    vehicles =
      Vehicle
      |> join(:left, [v], cd in Driver, on: v.cab_driver_id == cd.id)

    vehicles =
      if !is_nil(query) && is_binary(query) && String.trim(query) != "" do
        formatted_query = "%#{String.downcase(String.trim(query))}%"

        vehicles
        |> where(
          [v, cd],
          fragment("LOWER(?) LIKE ?", v.vehicle_model, ^formatted_query) or
            fragment("LOWER(?) LIKE ?", v.vehicle_number, ^formatted_query) or
            fragment("LOWER(?) LIKE ?", cd.name, ^formatted_query) or
            fragment("LOWER(?) LIKE ?", cd.phone_number, ^formatted_query) or
            fragment("LOWER(?) LIKE ?", v.garage_location, ^formatted_query)
        )
      else
        vehicles
      end

    vehicles =
      if not is_nil(params["is_vehicle_assigned"]) do
        vehicles |> where([v, cd], v.is_vehicle_assigned == ^params["is_vehicle_assigned"])
      else
        vehicles
      end

    vehicles =
      if not is_nil(params["city_id"]) do
        vehicles |> where([v, cd], v.city_id == ^params["city_id"])
      else
        vehicles
      end

    vehicles =
      if is_nil(hide_blacklisted) or hide_blacklisted == 'true' or not is_nil(params["booking_request_id"]) or
           not is_nil(params["is_vehicle_assigned"]) do
        vehicles |> where([v], v.is_blacklisted == false)
      else
        vehicles
      end

    vehicles =
      if not is_nil(params["is_available_for_rerouting"]) and params["is_available_for_rerouting"] == "true" do
        vehicles |> where([v], v.is_available_for_rerouting == true)
      else
        vehicles
      end

    vehicles =
      if not is_nil(params["booking_request_id"]) do
        booking_request_id =
          if is_binary(params["booking_request_id"]),
            do: String.to_integer(params["booking_request_id"]),
            else: params["booking_request_id"]

        booking_request = Repo.get_by(BookingRequest, id: booking_request_id)
        beginning_of_day = Timex.beginning_of_day(booking_request.pickup_time)
        end_of_day = Timex.end_of_day(booking_request.pickup_time)

        vehicles_assigned =
          BookingRequest
          |> where([b], b.status_id == ^Status.get_status_id("driver_assigned"))
          |> where([b], b.pickup_time >= ^beginning_of_day)
          |> where([b], b.pickup_time <= ^end_of_day)
          |> where([b], not is_nil(b.cab_vehicle_id))
          |> Repo.all()
          |> Enum.map(& &1.cab_vehicle_id)

        vehicles |> where([v], v.id not in ^vehicles_assigned)
      else
        vehicles
      end

    vehicles = vehicles |> where([v], is_nil(v.is_deleted) or v.is_deleted == false)

    vehicles =
      vehicles
      |> offset(^offset)
      |> limit(^limit)
      |> order_by([v], desc: v.inserted_at)
      |> Repo.all()
      |> Repo.preload([:cab_operator, :cab_driver, :city])

    vehicles_details =
      vehicles
      |> Enum.map(fn vehicle ->
        Vehicle.get_data(vehicle, true)
      end)

    %{
      "vehicles" => vehicles_details,
      "next_page_exists" => Enum.count(vehicles) >= limit,
      "next_page_query_params" => "p=#{page_no + 1}"
    }
  end

  defp validate_driver_assigned(changeset) do
    case changeset.valid? do
      true ->
        is_deleted = get_field(changeset, :is_deleted)
        id = get_field(changeset, :id)

        if not is_nil(id) and is_deleted == true and not is_nil(changeset.changes[:is_deleted]) do
          assignedBooking =
            BookingRequest
            |> where([b], b.cab_vehicle_id == ^id and b.status_id == ^Status.get_status_id("driver_assigned"))
            |> Repo.all()
            |> List.last()

          if not is_nil(assignedBooking) do
            add_error(
              changeset,
              :is_deleted,
              "Vehicle cannot be marked as deleted as already assigned to booking id #{assignedBooking.id}"
            )
          else
            changeset
          end
        else
          changeset
        end

      _ ->
        changeset
    end
  end

  defp validate_driver_city(changeset) do
    case changeset.valid? do
      true ->
        cab_driver_id = get_field(changeset, :cab_driver_id)
        id = get_field(changeset, :id)

        if not is_nil(id) and not is_nil(changeset.changes[:cab_driver_id]) and is_nil(changeset.changes[:city_id]) do
          driver = Repo.get(Driver, cab_driver_id)
          vehicle = Repo.get(Vehicle, id)

          if vehicle.city_id != driver.city_id do
            add_error(changeset, :cab_driver_id, "Vehicle and driver belong to different city")
          else
            changeset
          end
        else
          if not is_nil(id) and not is_nil(changeset.changes[:cab_driver_id]) and
               not is_nil(changeset.changes[:city_id]) do
            driver = Repo.get(Driver, cab_driver_id)
            # vehicle = Repo.get(Vehicle, id)
            if changeset.changes[:city_id] != driver.city_id do
              add_error(changeset, :cab_driver_id, "Vehicle and driver belong to different city")
            else
              changeset
            end
          else
            changeset
          end
        end

      _ ->
        changeset
    end
  end
end
