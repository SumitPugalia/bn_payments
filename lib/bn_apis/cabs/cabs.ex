defmodule BnApis.Cabs do
  @moduledoc """
  The Cabs context.
  """

  import Ecto.Query, warn: false
  alias BnApis.Repo
  alias BnApis.Organizations.Broker
  alias BnApis.Cabs.BookingRequest
  alias BnApis.Cabs.BookingRequestLog
  alias BnApis.Cabs.Status
  alias BnApis.Cabs.Operator
  alias BnApis.Cabs.Vehicle
  alias BnApis.Cabs.Driver
  alias BnApis.Cabs.BookingSlot
  alias BnApis.Helpers.WhatsappHelper

  # Apis for App
  def create_booking_request(params, session_data) do
    broker_id = session_data |> get_in(["profile", "broker_id"])
    organization_id = session_data |> get_in(["profile", "organization_id"])
    params = process_booking_request_params(params)
    params = Map.put(params, "broker_id", broker_id)
    params = Map.put(params, "organization_id", organization_id)
    params = Map.put(params, "status", "requested")
    broker = Broker |> where([b], b.id == ^broker_id) |> Repo.one()
    city_id = broker.operating_city

    case params do
      %{
        "client_name" => _client_name,
        "pickup_time" => _pickup_time,
        "latitude" => _latitude,
        "longitude" => _longitude,
        "project_ids" => _project_ids,
        "address" => _address
      } ->
        # current_epoch_time = DateTime.utc_now() |> DateTime.to_unix()
        is_pickup_epoch_time_invalid = !is_pickup_epoch_time_valid?(params["pickup_time"], city_id)
        has_broker_daily_limit_reached = has_broker_daily_limit_reached?(broker_id)

        cond do
          has_broker_daily_limit_reached ->
            {:error, "Your daily limit has been reached"}

          is_pickup_epoch_time_invalid ->
            {:error, "Bookings not allowed for the given pickup date and time."}

          true ->
            Repo.transaction(fn ->
              try do
                booking_request = BookingRequest.create_booking_request!(params)
                %{"id" => booking_request.id}
              rescue
                err ->
                  message =
                    if not is_nil(err.changeset) and not is_nil(err.changeset.errors) do
                      try do
                        err.changeset.errors |> List.first() |> elem(1) |> elem(0)
                      rescue
                        _ ->
                          try do
                            err.changeset.errors |> List.first() |> elem(1)
                          rescue
                            _ ->
                              err.changeset.errors |> List.first()
                          end
                      end
                    else
                      Exception.message(err)
                    end

                  # find better way to propogate errors in changeset to front end
                  Repo.rollback(message)
              end
            end)
        end

      _ ->
        {:error, "Invalid params"}
    end
  end

  def create_reroute_booking(params, session_data) do
    employee_id = session_data |> get_in(["profile", "employee_id"])
    organization_id = session_data |> get_in(["profile", "organization_id"])
    params = Map.put(params, "status", "rerouting")
    params = Map.put(params, "organization_id", organization_id)
    params = Map.put(params, "user_id", employee_id)
    params = Map.put(params, "user_type", "employee")
    params = process_booking_request_params(params)
    broker_id = params["broker_id"]
    # broker = Broker |> where([b], b.id == ^broker_id) |> Repo.one()
    # city_id = broker.operating_city
    case params do
      %{
        "client_name" => _client_name,
        "pickup_time" => _pickup_time,
        "latitude" => _latitude,
        "longitude" => _longitude,
        "project_ids" => _project_ids,
        "address" => _address,
        "broker_id" => _broker_id
      } ->
        # is_pickup_epoch_time_invalid = !is_pickup_epoch_time_valid_for_reroute?(params["pickup_time"], city_id)
        has_broker_daily_limit_reached = has_broker_daily_limit_reached?(broker_id)

        cond do
          has_broker_daily_limit_reached ->
            {:error, "Broker daily limit has been reached"}

          # is_pickup_epoch_time_invalid ->
          #   {:error, "Bookings slots are closed for given date."}
          true ->
            Repo.transaction(fn ->
              try do
                booking_request = BookingRequest.create_booking_request!(params)
                %{"id" => booking_request.id}
              rescue
                _err ->
                  Repo.rollback("Unable to store data")
              end
            end)
        end

      _ ->
        {:error, "Invalid params"}
    end
  end

  def update_booking_request(params, session_data) do
    broker_id = session_data |> get_in(["profile", "broker_id"])
    params = process_booking_request_params(params)
    broker = Broker |> where([b], b.id == ^broker_id) |> Repo.one()
    city_id = broker.operating_city

    case params do
      %{
        "id" => id
      } ->
        booking_request = BookingRequest.get_booking_request(id)
        is_pickup_epoch_time_invalid = !is_pickup_epoch_time_valid?(params["pickup_time"], city_id)

        cond do
          is_nil(booking_request) ->
            {:error, "No such booking request found"}

          booking_request.broker_id != broker_id ->
            {:error, "You are not authorised to update this booking request"}

          booking_request.status_id != Status.get_status_id("requested") ->
            {:error, "Booking cannot be updated"}

          is_pickup_epoch_time_invalid ->
            {:error, "Bookings not allowed for the given pickup date and time."}

          booking_request.status_id == Status.get_status_id("rerouting") ->
            {:error, "Rerouting Booking cannot be updated"}

          true ->
            Repo.transaction(fn ->
              try do
                booking_request = BookingRequest.update_booking_request!(booking_request, params)
                %{"id" => booking_request.id}
              rescue
                err ->
                  Repo.rollback(Exception.message(err))
              end
            end)
        end

      _ ->
        {:error, "Invalid params"}
    end
  end

  def delete_booking_request(params, session_data) do
    broker_id = session_data |> get_in(["profile", "broker_id"])

    case params do
      %{
        "id" => id
      } ->
        booking_request = BookingRequest.get_booking_request(id)

        status_ids = [
          Status.get_status_id("requested"),
          Status.get_status_id("driver_assigned"),
          Status.get_status_id("rerouting")
        ]

        pickup_time = booking_request.pickup_time |> Timex.to_datetime() |> Timex.Timezone.convert("Asia/Kolkata")
        now = Timex.now() |> Timex.Timezone.convert("Asia/Kolkata")

        cond do
          is_nil(booking_request) ->
            {:error, "No such booking request found"}

          booking_request.broker_id != broker_id ->
            {:error, "You are not authorised to delete this booking request"}

          !Enum.member?(status_ids, booking_request.status_id) ->
            {:error, "Booking cannot be deleted"}

          DateTime.diff(pickup_time, now) <= 0 ->
            {:error, "Booking cannot be cancelled after pickup time"}

          true ->
            Repo.transaction(fn ->
              try do
                BookingRequest.delete_booking_request!(booking_request, params["rejection_reason"])
                %{"success" => true}
              rescue
                _ ->
                  Repo.rollback("Unable to delete booking")
              end
            end)
        end

      _ ->
        {:error, "Invalid params"}
    end
  end

  def get_all_booking_requests_for_broker(params, session_data) do
    broker_id = session_data |> get_in(["profile", "broker_id"])
    page_no = (params["p"] || "1") |> String.to_integer()
    response = BookingRequest.get_all_booking_request_for_broker(broker_id, page_no)
    {:ok, response}
  end

  defp process_booking_request_params(params) do
    params =
      if not is_nil(params["pickup_time"]) do
        pickup_epoch_time = if is_binary(params["pickup_time"]), do: String.to_integer(params["pickup_time"]), else: params["pickup_time"]

        {:ok, datetime} = DateTime.from_unix(pickup_epoch_time)
        params |> Map.put("pickup_time", datetime) |> Map.put("pickup_epoch_time", pickup_epoch_time)
      else
        params
      end

    params =
      if not is_nil(params["other_project_names"]) do
        params |> Map.put("other_project_names", Poison.decode!(params["other_project_names"]))
      else
        params
      end

    params =
      if not is_nil(params["project_uuids"]) && params["project_uuids"] != [] do
        project_uuids =
          if is_binary(params["project_uuids"]),
            do: params["project_uuids"] |> Poison.decode!(),
            else: params["project_uuids"] || []

        project_ids = BnApis.Stories.Story.stories_by_uuids(project_uuids) |> Enum.map(& &1.id)
        params |> Map.put("project_ids", project_ids)
      else
        params
      end

    params
  end

  defp has_broker_daily_limit_reached?(broker_id) do
    daily_max_request_count = 30
    status_id = Status.get_status_id("requested")

    today =
      Timex.now()
      |> Timex.Timezone.convert("Asia/Kolkata")
      |> Timex.beginning_of_day()

    brokers_bookings_count =
      Repo.one(
        from(l in BookingRequest,
          where: l.broker_id == ^broker_id,
          where: l.inserted_at >= ^today,
          where: l.status_id == ^status_id,
          select: count(l.id)
        )
      )

    brokers_bookings_count >= daily_max_request_count
  end

  def is_pickup_epoch_time_valid?(pickup_time, city_id) do
    pickup_time = pickup_time |> Timex.Timezone.convert("Asia/Kolkata")
    pickup_time_day = pickup_time |> Timex.beginning_of_day()
    slot_details = BookingSlot.get_slot_details(pickup_time_day, city_id)
    now = Timex.now() |> Timex.Timezone.convert("Etc/UTC") |> Timex.Timezone.convert("Asia/Kolkata") |> DateTime.to_unix()
    pickup_time = pickup_time |> DateTime.to_unix()

    slot_details["start_date_time"] <= now and now <= slot_details["end_date_time"] and
      slot_details["booking_start_time"] <= pickup_time and pickup_time <= slot_details["booking_end_time"]
  end

  def is_pickup_epoch_time_valid_for_reroute?(pickup_time, city_id) do
    pickup_time = pickup_time |> Timex.Timezone.convert("Asia/Kolkata")
    pickup_time_day = pickup_time |> Timex.beginning_of_day()
    slot_details = BookingSlot.get_slot_details(pickup_time_day, city_id)
    pickup_time = pickup_time |> DateTime.to_unix()
    slot_details["booking_start_time"] <= pickup_time and pickup_time <= slot_details["booking_end_time"]
  end

  # Apis for employee
  def get_all_booking_requests(params, _session_data) do
    page_no = (params["p"] || "1") |> String.to_integer()

    start_time =
      case params["start_time"] do
        nil ->
          nil

        start_time when is_integer(start_time) ->
          {:ok, datetime} = DateTime.from_unix(start_time)
          datetime

        start_time when is_binary(start_time) ->
          {:ok, datetime} = String.to_integer(start_time) |> DateTime.from_unix()
          datetime

        _ ->
          nil
      end

    end_time =
      case params["end_time"] do
        nil ->
          nil

        end_time when is_integer(end_time) ->
          {:ok, datetime} = DateTime.from_unix(end_time)
          datetime

        end_time when is_binary(end_time) ->
          {:ok, datetime} = String.to_integer(end_time) |> DateTime.from_unix()
          datetime

        _ ->
          nil
      end

    broker_ids =
      case params["broker_ids"] do
        nil ->
          nil

        broker_ids when is_list(broker_ids) ->
          broker_ids

        broker_ids when is_binary(broker_ids) ->
          broker_ids |> String.split(",")

        _ ->
          nil
      end

    broker_ids =
      case params["assigned_broker_ids"] do
        nil ->
          broker_ids

        assigned_broker_ids ->
          if is_nil(broker_ids) do
            assigned_broker_ids
          else
            broker_ids -- broker_ids -- assigned_broker_ids
          end
      end

    response =
      BookingRequest.get_filtered_booking_requests(
        params["q"],
        page_no,
        params["status"],
        params["city_id"],
        start_time,
        end_time,
        broker_ids,
        params["project_id"]
      )

    {:ok, response}
  end

  def get_logs_for_booking_request(params, _session_data) do
    response = BookingRequestLog.get_logs_for_booking_request(params["id"], params["page"])
    {:ok, response}
  end

  def update_whatsapp_sent(params, session_data) do
    BookingRequest.update_whatsapp_sent(params["id"], session_data["user_id"])
    {:ok, %{"success" => true}}
  end

  def assign_vehicle_in_booking_request(params, session_data) do
    booking_request = BookingRequest.get_booking_request(params["id"])
    status_ids = [Status.get_status_id("deleted"), Status.get_status_id("completed")]
    employee_id = session_data["user_id"]

    cond do
      is_nil(booking_request) ->
        {:error, "No such booking request found"}

      !is_nil(params["assigned_broker_ids"]) && !Enum.member?(params["assigned_broker_ids"], booking_request.broker_id) ->
        {:error, "Operation not permitted"}

      Enum.member?(status_ids, booking_request.status_id) ->
        {:error, "Booking in deleted or completed status"}

      true ->
        Repo.transaction(fn ->
          try do
            BookingRequest.assign_cab!(%{
              booking_request: booking_request,
              vehicle_id: params["vehicle_id"],
              employee_id: employee_id
            })

            enqueue_send_notification(booking_request, "vehicle_assigned")
            %{"success" => true}
          rescue
            err ->
              Repo.rollback(Exception.message(err))
          end
        end)
    end
  end

  def update_vehicle_in_booking_request(params, session_data) do
    booking_request = BookingRequest.get_booking_request(params["id"])
    employee_id = session_data["user_id"]

    cond do
      is_nil(booking_request) ->
        {:error, "No such booking request found"}

      !is_nil(params["assigned_broker_ids"]) && !Enum.member?(params["assigned_broker_ids"], booking_request.broker_id) ->
        {:error, "Operation not permitted"}

      booking_request.status_id != Status.get_status_id("driver_assigned") ->
        {:error, "Booking not in driver assigned status"}

      true ->
        Repo.transaction(fn ->
          try do
            BookingRequest.assign_cab!(%{
              booking_request: booking_request,
              vehicle_id: params["vehicle_id"],
              employee_id: employee_id
            })

            enqueue_send_notification(booking_request, "vehicle_updated")
            %{"success" => true}
          rescue
            err ->
              Repo.rollback(Exception.message(err))
          end
        end)
    end
  end

  def mark_completed(params, session_data) do
    employee_id = session_data && session_data["user_id"]

    case params do
      %{
        "id" => id
      } ->
        booking_request = BookingRequest.get_booking_request(id)

        cond do
          is_nil(booking_request) ->
            {:error, "No such booking request found"}

          booking_request.status_id != Status.get_status_id("driver_assigned") ->
            {:error, "Request cannot be marked completed"}

          true ->
            Repo.transaction(fn ->
              try do
                BookingRequest.mark_completed!(booking_request, employee_id)
                %{"success" => true}
              rescue
                err ->
                  Repo.rollback(Exception.message(err))
              end
            end)
        end

      _ ->
        {:error, "Invalid params"}
    end
  end

  def cancel_request(params, session_data) do
    employee_id = session_data && session_data["user_id"]

    case params do
      %{
        "id" => id
      } ->
        booking_request = BookingRequest.get_booking_request(id)

        status_ids = [
          Status.get_status_id("requested"),
          Status.get_status_id("driver_assigned"),
          Status.get_status_id("rerouting")
        ]

        cond do
          is_nil(booking_request) ->
            {:error, "No such booking request found"}

          !is_nil(params["assigned_broker_ids"]) &&
              !Enum.member?(params["assigned_broker_ids"], booking_request.broker_id) ->
            {:error, "Operation not permitted"}

          !Enum.member?(status_ids, booking_request.status_id) ->
            {:error, "Booking cannot be cancelled"}

          true ->
            Repo.transaction(fn ->
              try do
                BookingRequest.cancel_booking_request!(
                  booking_request,
                  employee_id,
                  params["rejection_reason"],
                  params["is_available_for_rerouting"]
                )

                enqueue_send_notification(booking_request, "booking_rejected")
                %{"success" => true}
              rescue
                err ->
                  Repo.rollback(Exception.message(err))
              end
            end)
        end

      _ ->
        {:error, "Invalid params"}
    end
  end

  def enqueue_send_notification(booking_request, identifier) do
    Exq.enqueue(
      Exq,
      "send_notification",
      BnApis.SendCabNotificationWorker,
      [booking_request.id, identifier]
    )
  end

  # Operator CRUD Apis

  def list_cab_operators(_params, _session_data) do
    operators =
      Operator
      |> where([o], is_nil(o.is_deleted) or o.is_deleted == false)
      |> order_by([o], desc: o.inserted_at)
      |> Repo.all()
      |> Enum.map(fn operator ->
        Operator.get_data(operator)
      end)

    {:ok, %{"operators" => operators}}
  end

  def create_operator(params, _session_data) do
    case params do
      %{"name" => _name} ->
        Repo.transaction(fn ->
          try do
            operator = Operator.create!(params)
            Operator.get_data(operator)
          rescue
            _ ->
              Repo.rollback("Unable to store data")
          end
        end)

      _ ->
        {:error, "Invalid params"}
    end
  end

  def update_operator(params, _session_data) do
    case params do
      %{"id" => id} ->
        case Repo.get(Operator, id) do
          nil ->
            {:error, "Operator not found"}

          operator ->
            Repo.transaction(fn ->
              try do
                operator = Operator.update!(operator, params)
                Operator.get_data(operator)
              rescue
                err ->
                  Repo.rollback(Exception.message(err))
              end
            end)
        end

      _ ->
        {:error, "Invalid params"}
    end
  end

  # Vehicle CRUD Apis

  def list_cab_vehicles(params, _session_data) do
    response = Vehicle.get_vehicles_list(params)
    {:ok, response}
  end

  def get_cab_vehicle_data(params, _session_data) do
    response = Vehicle.get_vehicle_data(params)
    {:ok, response}
  end

  def create_vehicle(params, _session_data) do
    case params do
      %{
        "vehicle_model" => _vehicle_model,
        "vehicle_number" => _vehicle_number,
        "vehicle_type" => _vehicle_type,
        "number_of_seats" => _number_of_seats,
        "cab_driver_id" => _cab_driver_id,
        "cab_operator_id" => _cab_operator_id,
        "city_id" => _city_id
      } ->
        case Vehicle.check_vehicle(params["vehicle_number"]) do
          nil ->
            Repo.transaction(fn ->
              try do
                vehicle = Vehicle.create!(params)
                Vehicle.get_data(vehicle, nil)
              rescue
                err ->
                  Repo.rollback(Exception.message(err))
              end
            end)

          _ ->
            {:error, "Vehicle with given number already exists"}
        end

      _ ->
        {:error, "Invalid params"}
    end
  end

  def update_vehicle(params, _session_data) do
    case params do
      %{"id" => id} ->
        case Repo.get(Vehicle, id) do
          nil ->
            {:error, "Vehicle not found"}

          vehicle ->
            Repo.transaction(fn ->
              try do
                if not is_nil(params["cab_driver_id"]) do
                  assigned_vehicle =
                    Vehicle
                    |> where(
                      [v],
                      (is_nil(v.is_deleted) or v.is_deleted == false) and v.cab_driver_id == ^params["cab_driver_id"] and
                        v.id != ^params["id"]
                    )
                    |> Repo.all()
                    |> List.last()

                  if not is_nil(assigned_vehicle) do
                    driver_assigned_booking =
                      BookingRequest
                      |> where(
                        [b],
                        b.cab_vehicle_id == ^assigned_vehicle.id and
                          b.status_id == ^Status.get_status_id("driver_assigned")
                      )
                      |> Repo.all()
                      |> List.last()

                    if not is_nil(driver_assigned_booking) do
                      Repo.rollback("Driver already assigned to a booking in progress.")
                    else
                      Vehicle.update!(assigned_vehicle, %{"cab_driver_id" => vehicle.cab_driver_id})
                    end
                  end
                end

                vehicle = Vehicle.update!(vehicle, params)
                Vehicle.get_data(vehicle, nil)
              rescue
                err ->
                  Repo.rollback(Exception.message(err))
              end
            end)
        end

      _ ->
        {:error, "Invalid params"}
    end
  end

  # Driver CRUD Apis

  def list_cab_drivers(params, _session_data) do
    page_no = (params["p"] || "1") |> String.to_integer()
    response = Driver.get_drivers_list(params["q"], page_no, params["city_id"], params["hide_blacklisted"])
    {:ok, response}
  end

  def create_driver(params, _session_data) do
    case params do
      %{
        "name" => _name,
        "phone_number" => _phone_number,
        "cab_operator_id" => _cab_operator_id,
        "city_id" => _city_id
      } ->
        case Driver.check_driver(params["phone_number"]) do
          nil ->
            Repo.transaction(fn ->
              try do
                driver = Driver.create!(params)
                Driver.get_data(driver)
              rescue
                err ->
                  Repo.rollback(Exception.message(err))
              end
            end)

          _ ->
            {:error, "Driver with phone already exists"}
        end

      _ ->
        {:error, "Invalid params"}
    end
  end

  def update_driver(params, _session_data) do
    case params do
      %{"id" => id} ->
        case Repo.get(Driver, id) do
          nil ->
            {:error, "Driver not found"}

          driver ->
            Repo.transaction(fn ->
              try do
                driver = Driver.update!(driver, params)
                Driver.get_data(driver)
              rescue
                err ->
                  Repo.rollback(Exception.message(err))
              end
            end)
        end

      _ ->
        {:error, "Invalid params"}
    end
  end

  def create_booking_slot(params, session_data) do
    employee_id = session_data && session_data["user_id"]
    params = process_booking_slot_params(params)

    booking_slot =
      BookingSlot
      |> where([bs], bs.slot_date == ^params["slot_date"] and bs.city_id == ^params["city_id"])
      |> Repo.one()

    case params do
      %{
        "slot_date" => _slot_date,
        "start_date_time" => _start_date_time,
        "end_date_time" => _end_date_time,
        "is_slot_start_open" => _is_slot_start_open,
        "booking_start_time" => _booking_start_time,
        "booking_end_time" => _booking_end_time,
        "city_id" => _city_id
      } ->
        case booking_slot do
          nil ->
            Repo.transaction(fn ->
              try do
                params = Map.put(params, "user_id", employee_id)
                booking_slot = BookingSlot.create!(params)
                BookingSlot.get_slot_data(booking_slot)
              rescue
                error ->
                  Repo.rollback(Exception.message(error))
              end
            end)

          _ ->
            {:error, "BookingSlot for the date already exists"}
        end

      _ ->
        {:error, "Invalid params"}
    end
  end

  def update_booking_slot(params, session_data) do
    employee_id = session_data && session_data["user_id"]
    params = process_booking_slot_params(params)

    case params do
      %{
        "id" => id,
        "slot_date" => _slot_date,
        "start_date_time" => _start_date_time,
        "end_date_time" => _end_date_time,
        "booking_start_time" => _booking_start_time,
        "booking_end_time" => _booking_end_time,
        "is_slot_start_open" => _is_slot_start_open,
        "city_id" => _city_id
      } ->
        case Repo.get(BookingSlot, id) do
          nil ->
            {:error, "BookingSlot not found"}

          booking_slot ->
            Repo.transaction(fn ->
              try do
                params = Map.put(params, "user_id", employee_id)
                booking_slot = BookingSlot.update!(booking_slot, params)
                BookingSlot.get_slot_data(booking_slot)
              rescue
                error ->
                  Repo.rollback(Exception.message(error))
              end
            end)
        end

      _ ->
        {:error, "Invalid params"}
    end
  end

  def get_booking_slot(params) do
    params = process_booking_slot_params(params)

    case params do
      %{
        "slot_date" => slot_date
      } ->
        BookingSlot.get_slot_details(slot_date, params["city_id"])

      _ ->
        {:error, "Invalid params"}
    end
  end

  defp process_booking_slot_params(params) do
    params =
      if not is_nil(params["slot_date"]) do
        slot_date = if is_binary(params["slot_date"]), do: String.to_integer(params["slot_date"]), else: params["slot_date"]

        {:ok, datetime} = DateTime.from_unix(slot_date)
        params |> Map.put("slot_date", datetime)
      else
        params
      end

    params =
      if not is_nil(params["start_date_time"]) do
        start_date_time =
          if is_binary(params["start_date_time"]),
            do: String.to_integer(params["start_date_time"]),
            else: params["start_date_time"]

        {:ok, datetime} = DateTime.from_unix(start_date_time)
        params |> Map.put("start_date_time", datetime)
      else
        params
      end

    params =
      if not is_nil(params["end_date_time"]) do
        end_date_time =
          if is_binary(params["end_date_time"]),
            do: String.to_integer(params["end_date_time"]),
            else: params["end_date_time"]

        {:ok, datetime} = DateTime.from_unix(end_date_time)
        params |> Map.put("end_date_time", datetime)
      else
        params
      end

    params =
      if not is_nil(params["booking_start_time"]) do
        start_date_time =
          if is_binary(params["booking_start_time"]),
            do: String.to_integer(params["booking_start_time"]),
            else: params["booking_start_time"]

        {:ok, datetime} = DateTime.from_unix(start_date_time)
        params |> Map.put("booking_start_time", datetime)
      else
        params
      end

    params =
      if not is_nil(params["booking_end_time"]) do
        end_date_time =
          if is_binary(params["booking_end_time"]),
            do: String.to_integer(params["booking_end_time"]),
            else: params["booking_end_time"]

        {:ok, datetime} = DateTime.from_unix(end_date_time)
        params |> Map.put("booking_end_time", datetime)
      else
        params
      end

    params
  end

  def list_booking_slots(city_id) do
    response = BookingSlot.get_booking_slot_list(city_id)
    {:ok, response}
  end

  def send_messages_for_booked_cabs(params) do
    response = BookingRequest.send_messages_for_booked_cabs(params)
    {:ok, response}
  end

  def send_message(params) do
    response =
      if params["to"] == "drivers" do
        WhatsappHelper.send_message_to_all_drivers(params["message"], params["city_id"])
      else
        WhatsappHelper.send_message_to_all_phones(params["message"], params["phones"])
      end

    {:ok, response}
  end

  def get_valid_pickup_dates_and_times() do
    today = Timex.now() |> Timex.Timezone.convert("Asia/Kolkata")
    beginning_of_day = Timex.beginning_of_day(today)
    hour_of_the_day = Timex.diff(today, beginning_of_day, :hours)
    this_sun = Timex.end_of_week(beginning_of_day, :mon) |> Timex.beginning_of_day()
    this_sat = Timex.shift(this_sun, days: -1)

    dates =
      cond do
        Timex.days_to_end_of_week(beginning_of_day, :mon) > 2 ->
          [Timex.beginning_of_day(this_sat), Timex.beginning_of_day(this_sun)]

        Timex.days_to_end_of_week(beginning_of_day, :mon) == 2 and hour_of_the_day < 21 ->
          [Timex.beginning_of_day(this_sat), Timex.beginning_of_day(this_sun)]

        Timex.days_to_end_of_week(beginning_of_day, :mon) < 2 ->
          next_mon = Timex.shift(this_sun, days: 1)
          next_sun = Timex.end_of_week(next_mon, :mon)
          next_sat = Timex.shift(next_sun, days: -1)
          [Timex.beginning_of_day(this_sun), Timex.beginning_of_day(next_sun), Timex.beginning_of_day(next_sat)]

        true ->
          next_mon = Timex.shift(this_sun, days: 1)
          next_sun = Timex.end_of_week(next_mon, :mon)
          next_sat = Timex.shift(next_sun, days: -1)
          [Timex.beginning_of_day(next_sat), Timex.beginning_of_day(next_sun)]
      end

    dates =
      dates
      |> Enum.map(fn t ->
        t |> DateTime.to_unix()
      end)

    timings = %{
      "start_time" => 9,
      "end_time" => 15
    }

    {dates, timings}
  end

  def meta() do
    {dates, timings} = get_valid_pickup_dates_and_times()
    {:ok, %{"dates" => dates, "timings" => timings}}
  end
end
