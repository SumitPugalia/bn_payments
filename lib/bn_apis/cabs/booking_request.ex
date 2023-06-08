defmodule BnApis.Cabs.BookingRequest do
  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query
  alias BnApis.Organizations.Broker
  alias BnApis.Cabs.BookingRequest
  alias BnApis.Cabs.BookingRequestLog
  alias BnApis.Stories.Story
  alias BnApis.Cabs.Status
  alias BnApis.Organizations.Broker
  alias BnApis.Organizations.Organization
  alias BnApis.Repo
  alias BnApis.Cabs.Vehicle
  alias BnApis.Cabs.Driver
  alias BnApis.AssignedBrokers
  alias BnApis.Accounts.Credential
  alias BnApis.Helpers.ApplicationHelper
  alias BnApis.Helpers.ExternalApiHelper
  alias BnApis.Accounts.EmployeeCredential
  alias BnApis.Helpers.{WhatsappHelper, Time}
  alias BnApis.Places.City
  alias BnApis.Rewards.RewardsLead
  alias BnApis.Rewards.RewardsLeadStatus
  alias BnApis.Helpers.Time
  alias BnApis.Accounts.ProfileType

  schema "cab_booking_requests" do
    field :client_name, :string
    field :project_ids, {:array, :integer}, default: []
    field :other_project_names, {:array, :string}, default: []
    field :pickup_time, :naive_datetime
    field :latitude, :string
    field :longitude, :string
    field :address, :string
    field :sub_locality, :string
    field :locality, :string
    field :rejection_reason, :string
    field :sms_sent, :boolean, default: false
    field :whatsapp_sent, :boolean, default: false
    field :no_of_persons, :integer
    field :status_id, :integer
    field :user_id, :integer
    field :user_type, :string
    belongs_to(:broker, Broker)
    belongs_to(:cab_vehicle, Vehicle)
    belongs_to(:city, City)
    belongs_to(:old_broker, Broker)
    belongs_to(:old_organization, Organization)
    timestamps()
  end

  @required [
    :client_name,
    :project_ids,
    :pickup_time,
    :latitude,
    :longitude,
    :address,
    :broker_id,
    :status_id,
    :city_id,
    :old_broker_id,
    :old_organization_id
  ]
  @optional [
    :cab_vehicle_id,
    :no_of_persons,
    :other_project_names,
    :sms_sent,
    :sub_locality,
    :locality,
    :whatsapp_sent,
    :rejection_reason,
    :user_id,
    :user_type
  ]
  @draft_reward_status_id 6
  @delete_reward_status_id 7
  @customer_supper_phone_no "+91 77380 46786"

  @booking_success_whatsapp_template "booking1"
  @booking_cancel_whatsapp_template "bookingcancel"

  @doc false
  def changeset(booking_request, attrs) do
    booking_request
    |> cast(attrs, @required ++ @optional)
    |> validate_required(@required)
    |> validate_vehicle_assignment()
    |> validate_vehicle_city()
    |> validate_delete_booking_request()
    |> unique_constraint(:unique_booking_req,
      name: :booking_req_unique_index,
      message: "same booking request already exists."
    )
  end

  def create_booking_request!(params) do
    {sub_locality, locality} = BookingRequest.get_locality_from_lat_lng(params["latitude"], params["longitude"])
    broker = Broker |> where([b], b.id == ^params["broker_id"]) |> Repo.one()
    city_id = broker.operating_city

    ch =
      BookingRequest.changeset(%BookingRequest{}, %{
        client_name: params["client_name"],
        project_ids: params["project_ids"],
        other_project_names: params["other_project_names"],
        pickup_time: params["pickup_time"],
        latitude: params["latitude"],
        longitude: params["longitude"],
        address: params["address"],
        no_of_persons: params["no_of_persons"],
        broker_id: params["broker_id"],
        status_id: Status.get_status_id(params["status"]),
        sub_locality: sub_locality,
        city_id: city_id,
        locality: locality,
        user_id: params["user_id"],
        user_type: params["user_type"],
        old_broker_id: params["broker_id"],
        old_organization_id: params["organization_id"]
      })

    booking_request = Repo.insert!(ch)
    [user_type, user_id] = get_user_type(params)
    BookingRequestLog.log(booking_request, user_id, user_type, ch)

    # assigned_broker = AssignedBrokers.fetch_one_broker(params["broker_id"])
    # employee_credential_id = if not is_nil(assigned_broker) do
    #   assigned_broker.employees_credentials_id
    # else
    #   nil
    # end
    #
    # # hiding this feature for now
    # Story |> where([s], s.id in ^params["project_ids"] and s.is_rewards_enabled == ^true) |> Repo.all() |> Enum.each(fn story ->
    #   RewardsLead.create_draft_rewards_lead!(
    #     params["client_name"],
    #     params["broker_id"],
    #     story.id,
    #     employee_credential_id,
    #     booking_request.id,
    #     params["pickup_time"],
    #     story.story_tier_id
    #   )
    # end)
    booking_request
  end

  def get_user_type(params) do
    if params["status"] == "rerouting" do
      [ProfileType.employee().name, params["user_id"]]
    else
      [ProfileType.broker().name, params["broker_id"]]
    end
  end

  def update_booking_request!(booking_request, params) do
    params =
      params
      |> Map.take([
        "client_name",
        "project_ids",
        "other_project_names",
        "pickup_time",
        "latitude",
        "longitude",
        "address",
        "no_of_persons"
      ])

    params =
      if not is_nil(params["latitude"]) and not is_nil(params["longitude"]) do
        {sub_locality, locality} = BookingRequest.get_locality_from_lat_lng(params["latitude"], params["longitude"])
        params = Map.put(params, "sub_locality", sub_locality)
        Map.put(params, "locality", locality)
      else
        params
      end

    ch = BookingRequest.changeset(booking_request, params)
    booking_request = Repo.update!(ch)
    BookingRequestLog.log(booking_request, booking_request.broker_id, "broker", ch)
    booking_request
  end

  def update_whatsapp_sent(booking_request_id, user_id) do
    booking_request = Repo.get(BookingRequest, booking_request_id)
    ch = BookingRequest.changeset(booking_request, %{"whatsapp_sent" => true})
    booking_request = Repo.update!(ch)
    BookingRequestLog.log(booking_request, user_id, "employee", ch)
    booking_request
  end

  def delete_booking_request!(booking_request, rejection_reason) do
    deleted_status_id = Status.get_status_id("deleted")

    if booking_request.status_id == Status.get_status_id("driver_assigned") do
      send_message_on_delete_after_driver_assigned(booking_request)
    end

    ch =
      BookingRequest.changeset(booking_request, %{
        "status_id" => deleted_status_id,
        "rejection_reason" => rejection_reason
      })

    booking_request = Repo.update!(ch)
    BookingRequestLog.log(booking_request, booking_request.broker_id, "broker", ch)

    RewardsLead
    |> join(:inner, [rl], ls in RewardsLeadStatus, on: rl.latest_status_id == ls.id)
    |> where([rl, ls], rl.cab_booking_requests_id == ^booking_request.id and ls.status_id == ^@draft_reward_status_id)
    |> Repo.all()
    |> Enum.each(fn rld ->
      RewardsLeadStatus.create_rewards_lead_status_by_backend!(
        rld,
        @delete_reward_status_id,
        "Correspoding cab booking request deleted by broker"
      )
    end)

    booking_request
  end

  def get_all_booking_request_for_broker(broker_id, page_no) do
    limit = 30
    offset = (page_no - 1) * limit
    deleted_status_id = Status.get_status_id("deleted")

    booking_requests =
      BookingRequest
      |> where([b], b.broker_id == ^broker_id and b.status_id != ^deleted_status_id)
      |> order_by([b], desc: b.inserted_at)
      |> limit(^limit)
      |> offset(^offset)
      |> Repo.all()
      |> Repo.preload([:cab_vehicle, :city])

    project_details =
      booking_requests
      |> Enum.map(& &1.project_ids)
      |> List.flatten()
      |> Story.stories_by_ids()
      |> Enum.reduce(%{}, fn story, acc ->
        polygon_name =
          if not is_nil(story.polygon) do
            if is_nil(story.polygon.name), do: nil, else: story.polygon.name
          else
            nil
          end

        Map.put(acc, story.id, %{
          "uuid" => story.uuid,
          "name" => story.name,
          "polygon_name" => polygon_name
        })
      end)

    employee_broker_mapping = AssignedBrokers.fetch_one_broker(broker_id)

    employee_credentials =
      if not is_nil(employee_broker_mapping),
        do: Repo.get(EmployeeCredential, employee_broker_mapping.employees_credentials_id),
        else: nil

    booking_details =
      booking_requests
      |> Enum.map(fn br ->
        project_details = Enum.map(br.project_ids, fn project_id -> project_details[project_id] end) |> Enum.reject(&is_nil(&1))

        vehicle = br.cab_vehicle

        %{
          "id" => br.id,
          "client_name" => br.client_name,
          "projects" => project_details,
          "other_project_names" => br.other_project_names,
          "pickup_time" => Time.naive_second_to_millisecond(br.pickup_time),
          "pickup_time_unix" => br.pickup_time |> Time.naive_to_epoch_in_sec(),
          "latitude" => br.latitude,
          "longitude" => br.longitude,
          "address" => br.address,
          "no_of_persons" => br.no_of_persons,
          "status" => Status.status_list()[br.status_id],
          "vehicle" => Vehicle.get_data(vehicle, nil),
          "sub_locality" => br.sub_locality,
          "locality" => br.locality,
          "city" => br.city.name,
          "city_id" => br.city.id,
          "customer_support" => if(not is_nil(employee_credentials), do: employee_credentials.phone_number, else: @customer_supper_phone_no),
          "is_rerouting_booking" => if(not is_nil(br.user_type) && String.downcase(br.user_type) == "employee", do: true, else: false)
        }
      end)

    %{
      "booking_requests" => booking_details,
      "next_page_exists" => Enum.count(booking_requests) >= limit,
      "next_page_query_params" => "p=#{page_no + 1}"
    }
  end

  def format_pickup_time(pickup_time) do
    pickup_time
    |> Timex.Timezone.convert("Etc/UTC")
    |> Timex.Timezone.convert("Asia/Kolkata")
    |> Timex.format!("%I:%M %P, %d %b, %Y", :strftime)
  end

  def get_filtered_booking_requests(q, page_no, status, city_id, start_time, end_time, broker_ids, project_id) do
    limit = 30
    offset = (page_no - 1) * limit
    status_id = Status.get_status_id(status)

    booking_requests =
      BookingRequest
      |> join(:left, [b], bro in Broker, on: b.broker_id == bro.id)
      |> join(:left, [b, bro], c in Credential, on: c.broker_id == bro.id)
      |> join(:left, [b, bro, c], v in Vehicle, on: b.cab_vehicle_id == v.id)
      |> join(:left, [b, bro, c, v], d in Driver, on: v.cab_driver_id == d.id)

    {intVal, strPart} = if not is_nil(q), do: if(Integer.parse(q) == :error, do: {nil, nil}, else: Integer.parse(q)), else: {nil, nil}

    booking_request = if not is_nil(q) and not is_nil(intVal) and strPart == "", do: Repo.get_by(BookingRequest, id: q), else: nil

    booking_requests =
      if not is_nil(booking_request) do
        booking_requests |> where([b], b.id == ^q)
      else
        booking_requests
      end

    booking_requests =
      if not is_nil(project_id) do
        booking_requests |> where([br], ^project_id in br.project_ids)
      else
        booking_requests
      end

    booking_requests =
      if is_nil(booking_request) && !is_nil(q) && is_binary(q) && String.trim(q) != "" do
        # broker name
        # broker phone number
        # vehicle number
        # driver name
        # driver number
        formatted_query = "%#{String.downcase(String.trim(q))}%"

        booking_requests
        |> where(
          [b, bro, c, v, d],
          fragment("LOWER(?) LIKE LOWER(?)", bro.name, ^formatted_query) or
            fragment("LOWER(?) LIKE ?", c.phone_number, ^formatted_query) or
            fragment("LOWER(?) LIKE ?", v.vehicle_number, ^formatted_query) or
            fragment("LOWER(?) LIKE ?", d.name, ^formatted_query) or
            fragment("LOWER(?) LIKE ?", d.phone_number, ^formatted_query)
        )
      else
        booking_requests
      end

    booking_requests =
      if !is_nil(status_id) do
        booking_requests |> where([b, bro, c, v, d], b.status_id == ^status_id)
      else
        booking_requests
      end

    booking_requests =
      if !is_nil(city_id) do
        booking_requests |> where([b, bro, c, v, d], b.city_id == ^city_id)
      else
        booking_requests
      end

    booking_requests =
      if !is_nil(start_time) do
        booking_requests |> where([b, bro, c, v, d], b.pickup_time >= ^start_time)
      else
        booking_requests
      end

    booking_requests =
      if !is_nil(end_time) do
        booking_requests |> where([b, bro, c, v, d], b.pickup_time <= ^end_time)
      else
        booking_requests
      end

    booking_requests =
      if is_list(broker_ids) and length(broker_ids) > 0 do
        booking_requests |> where([b, bro, c, v, d], b.broker_id in ^broker_ids)
      else
        booking_requests
      end

    status_wise_count =
      booking_requests
      |> group_by([b, bro, c, v, d], b.status_id)
      |> select([b, bro, c, v, d], {b.status_id, count(b.id)})
      |> Repo.all()

    all_count = status_wise_count |> Enum.map(&elem(&1, 1)) |> Enum.sum()
    status_list = Status.status_list()

    status_wise_count_response =
      status_wise_count
      |> Enum.reduce(%{"all" => all_count}, fn data, acc ->
        status = status_list |> get_in([elem(data, 0), "identifier"])
        Map.put(acc, status, elem(data, 1))
      end)

    booking_requests =
      booking_requests
      |> distinct(true)
      |> offset(^offset)
      |> limit(^limit)
      |> order_by([b, bro, c, v, d], desc: b.inserted_at)
      |> Repo.all()
      |> Repo.preload([:cab_vehicle, :city])

    project_details =
      booking_requests
      |> Enum.map(& &1.project_ids)
      |> List.flatten()
      |> Story.stories_by_ids()
      |> Enum.reduce(%{}, fn story, acc ->
        polygon_name =
          if not is_nil(story.polygon) do
            if is_nil(story.polygon.name), do: nil, else: story.polygon.name
          else
            nil
          end

        Map.put(acc, story.id, %{
          "uuid" => story.uuid,
          "name" => story.name,
          "polygon_name" => polygon_name
        })
      end)

    broker_details =
      booking_requests
      |> Enum.map(& &1.broker_id)
      |> Enum.uniq()
      |> Broker.fetch_broker_from_ids()
      |> Enum.reduce(%{}, fn broker, acc ->
        locality_name =
          if not is_nil(broker.polygon) do
            if is_nil(broker.polygon.locality), do: nil, else: broker.polygon.locality.name
          else
            nil
          end

        Map.put(acc, broker.id, %{
          "id" => broker.id,
          "name" => broker.name,
          "phone_number" => Broker.get_credential_data(broker)["phone_number"],
          "profile_image_url" => Broker.get_profile_image_url(broker),
          "locality_name" => locality_name
        })
      end)

    employee_details =
      booking_requests
      |> Enum.map(& &1.broker_id)
      |> Enum.uniq()
      |> AssignedBrokers.fetch_all_assignees_info()
      |> Enum.reduce(%{}, fn entity, acc ->
        Map.put(acc, entity.broker_id, %{
          "id" => entity.employee_id,
          "name" => entity.employee_name,
          "phone_number" => entity.employee_phone_number
        })
      end)

    booking_details =
      booking_requests
      |> Enum.map(fn br ->
        vehicle = br.cab_vehicle

        project_details = Enum.map(br.project_ids, fn project_id -> project_details[project_id] end) |> Enum.reject(&is_nil(&1))

        %{
          "id" => br.id,
          "client_name" => br.client_name,
          "projects" => project_details,
          "other_project_names" => br.other_project_names,
          "pickup_time" => Time.naive_second_to_millisecond(br.pickup_time),
          "latitude" => br.latitude,
          "longitude" => br.longitude,
          "sub_locality" => br.sub_locality,
          "locality" => br.locality,
          "city" => br.city.name,
          "city_id" => br.city_id,
          "sms_sent" => br.sms_sent,
          "whatsapp_sent" => br.whatsapp_sent,
          "rejection_reason" => br.rejection_reason,
          "address" => br.address,
          "created_at" => br.inserted_at,
          "no_of_persons" => br.no_of_persons,
          "status" => Status.status_list()[br.status_id],
          "vehicle" => Vehicle.get_data(vehicle, nil),
          "customer_support" =>
            if(not is_nil(employee_details[br.broker_id]),
              do: employee_details[br.broker_id]["phone_number"],
              else: @customer_supper_phone_no
            ),
          "broker_details" => broker_details[br.broker_id],
          "employee_details" => employee_details[br.broker_id],
          "request_raised_by" => get_user_by_user_id(br.user_id)
        }
      end)

    %{
      "booking_requests" => booking_details,
      "status_wise_count" => status_wise_count_response,
      "next_page_exists" => Enum.count(booking_requests) >= limit,
      "next_page_query_params" => "p=#{page_no + 1}"
    }
  end

  defp get_user_by_user_id(user_id) do
    if not is_nil(user_id) && user_id > 0 && user_id != "" do
      employee = Repo.get(EmployeeCredential, user_id)
      if not is_nil(employee), do: employee.name, else: ""
    else
      ""
    end
  end

  def cancel_booking_request!(booking_request, employee_id, rejection_reason, is_available_for_rerouting \\ false) do
    ch =
      BookingRequest.changeset(booking_request, %{
        "cab_vehicle_id" => nil,
        "sms_sent" => false,
        "status_id" => Status.get_status_id("cancelled"),
        "rejection_reason" => rejection_reason
      })

    Repo.update!(ch)
    BookingRequestLog.log(booking_request, employee_id, "employee", ch)

    RewardsLead
    |> join(:inner, [rl], ls in RewardsLeadStatus, on: rl.latest_status_id == ls.id)
    |> where([rl, ls], rl.cab_booking_requests_id == ^booking_request.id and ls.status_id == ^@draft_reward_status_id)
    |> Repo.all()
    |> Enum.each(fn rld ->
      RewardsLeadStatus.create_rewards_lead_status_by_backend!(
        rld,
        @delete_reward_status_id,
        "Correspoding cab booking request cancelled by employee with id #{employee_id}"
      )
    end)

    if not is_nil(booking_request.cab_vehicle_id) do
      Vehicle.assign(booking_request.cab_vehicle_id, false, is_available_for_rerouting)
      send_cancelled_message(booking_request)
    end
  end

  def mark_completed!(booking_request, employee_id) do
    ch = BookingRequest.changeset(booking_request, %{"status_id" => Status.get_status_id("completed")})
    Repo.update!(ch)
    BookingRequestLog.log(booking_request, employee_id, if(not is_nil(employee_id), do: "employee", else: "cron"), ch)
    Vehicle.assign(booking_request.cab_vehicle_id, false)
  end

  def assign_cab!(params) do
    booking_request = params.booking_request
    cab_vehicle_id = params.vehicle_id

    if !is_nil(booking_request.cab_vehicle_id) do
      Vehicle.assign(booking_request.cab_vehicle_id, false)
      send_cancelled_message(booking_request)
    end

    if is_nil(cab_vehicle_id) do
      ch =
        BookingRequest.changeset(booking_request, %{
          "cab_vehicle_id" => nil,
          "sms_sent" => false,
          "status_id" => Status.get_status_id("requested")
        })

      Repo.update!(ch)
      BookingRequestLog.log(booking_request, params.employee_id, "employee", ch)
    else
      ch =
        BookingRequest.changeset(booking_request, %{
          "cab_vehicle_id" => cab_vehicle_id,
          "status_id" => Status.get_status_id("driver_assigned")
        })

      Vehicle.assign(cab_vehicle_id, true)
      Repo.update!(ch)
      BookingRequestLog.log(booking_request, params.employee_id, "employee", ch)
    end

    send_message(booking_request)
  end

  def get_booking_request(id) do
    Repo.get_by(BookingRequest, id: id)
    |> Repo.preload([:broker, :cab_vehicle, cab_vehicle: [:cab_driver, :cab_operator]])
  end

  def send_message(booking_request) do
    if !is_nil(booking_request.cab_vehicle_id) do
      project_details =
        booking_request.project_ids
        |> Story.stories_by_ids()
        |> Enum.map(fn stry ->
          polygon_name = if is_nil(stry.polygon), do: "", else: stry.polygon.name
          stry.name <> " - " <> polygon_name
        end)

      other_project_names = booking_request.other_project_names
      project_names = (project_details ++ other_project_names) |> Enum.join(", ")
      id = Integer.to_string(booking_request.id)

      broker_details = booking_request.broker.name <> " - +91" <> Broker.get_credential_data(booking_request.broker)["phone_number"]

      pickup_time = BookingRequest.format_pickup_time(booking_request.pickup_time)

      google_link =
        "https://www.google.com/maps/search/?api=1&query=" <>
          booking_request.latitude <> "," <> booking_request.longitude

      cab_operator = booking_request.cab_vehicle.cab_operator
      operator_name = if not is_nil(cab_operator), do: cab_operator.name, else: "-"
      operator_number = if not is_nil(cab_operator), do: cab_operator.contact_number, else: "-"

      message =
        "New Booking from Broker Network \n\n Id: " <>
          id <>
          "\n Broker: " <>
          broker_details <>
          "\n" <>
          "Pick Up Time: " <>
          pickup_time <>
          "\n" <>
          "Location: " <>
          booking_request.address <>
          "\n" <>
          "Locality :" <>
          booking_request.sub_locality <>
          "\n" <> "Google Link: " <> google_link <> "\n" <> "Drop Projects: " <> project_names

      driver_phone =
        if String.contains?(booking_request.cab_vehicle.cab_driver.phone_number, "+91"),
          do: booking_request.cab_vehicle.cab_driver.phone_number,
          else: "+91" <> booking_request.cab_vehicle.cab_driver.phone_number

      whatsapp_response =
        WhatsappHelper.send_whatsapp_message(
          driver_phone,
          @booking_success_whatsapp_template,
          [
            "*" <> id <> "*",
            "*" <> broker_details <> "*",
            "*" <> pickup_time <> ".*",
            " " <> booking_request.address <> " - " <> booking_request.sub_locality <> " ",
            " " <> google_link <> " ",
            "*" <> operator_name <> "*",
            " " <> operator_number,
            "*+918976740652*"
          ],
          %{
            "customer_ref" => Integer.to_string(booking_request.cab_vehicle.cab_driver.id),
            "message_tag" => booking_request.cab_vehicle.vehicle_number,
            "conversation_id" => Integer.to_string(booking_request.id),
            "entity_type" => "cab_booking_requests",
            "entity_id" => booking_request.id
          }
        )

      if whatsapp_response.status_code == "200" do
        ch = BookingRequest.changeset(booking_request, %{"whatsapp_sent" => true})
        Repo.update!(ch)
      end

      driver_phone =
        if ApplicationHelper.get_should_send_sms() == "true",
          do: driver_phone,
          else: ApplicationHelper.get_default_sms_number()

      {:ok, response} = BnApis.Helpers.SmsService.send_sms(driver_phone, message, false, false)

      if response["sid"] && is_nil(response["error_message"]) do
        ch = BookingRequest.changeset(booking_request, %{"sms_sent" => true})
        Repo.update!(ch)
      end
    end
  end

  def send_cancelled_message(booking_request) do
    if !is_nil(booking_request.cab_vehicle_id) do
      id = Integer.to_string(booking_request.id)

      broker_details = booking_request.broker.name <> " - +91" <> Broker.get_credential_data(booking_request.broker)["phone_number"]

      pickup_time = BookingRequest.format_pickup_time(booking_request.pickup_time)

      message =
        "Booking Cancelled for \n\n Id: " <>
          id <>
          "\n Broker: " <>
          broker_details <> "\n" <> "Pick Up Time: " <> pickup_time <> "\n" <> "Location: " <> booking_request.address

      driver_phone =
        if String.contains?(booking_request.cab_vehicle.cab_driver.phone_number, "+91"),
          do: booking_request.cab_vehicle.cab_driver.phone_number,
          else: "+91" <> booking_request.cab_vehicle.cab_driver.phone_number

      WhatsappHelper.send_whatsapp_message(
        driver_phone,
        @booking_cancel_whatsapp_template,
        [
          "*" <> id <> "*",
          "*" <> broker_details <> "*",
          "*" <> pickup_time <> "*",
          "*" <> booking_request.address <> " - " <> booking_request.sub_locality <> "*"
        ],
        %{
          "customer_ref" => Integer.to_string(booking_request.cab_vehicle.cab_driver.id),
          "message_tag" => booking_request.cab_vehicle.vehicle_number,
          "conversation_id" => Integer.to_string(booking_request.id),
          "entity_type" => "cab_booking_requests",
          "entity_id" => booking_request.id
        }
      )

      driver_phone =
        if ApplicationHelper.get_should_send_sms() == "true",
          do: driver_phone,
          else: ApplicationHelper.get_default_sms_number()

      BnApis.Helpers.SmsService.send_sms(driver_phone, message, false, false)
    end
  end

  def send_message_on_delete_after_driver_assigned(booking_request) do
    if !is_nil(booking_request.cab_vehicle_id) do
      message =
        "Booking deleted for \n\n Id: " <>
          Integer.to_string(booking_request.id) <>
          "\n Broker: " <>
          booking_request.broker.name <>
          " - +91" <>
          Broker.get_credential_data(booking_request.broker)["phone_number"] <>
          "\n" <>
          "Pick Up Time: " <>
          BookingRequest.format_pickup_time(booking_request.pickup_time) <>
          "\n" <> "Location: " <> booking_request.address

      BnApis.Helpers.SmsService.send_sms("+918976740656", message, false)
    end
  end

  def send_messages_for_booked_cabs(params) do
    if params["all"] do
      BookingRequest
      |> where([b], b.status_id == ^Status.get_status_id("driver_assigned"))
      |> Repo.all()
      |> Enum.each(fn booking -> BookingRequest.send_message(BookingRequest.get_booking_request(booking.id)) end)
    else
      BookingRequest
      |> where(
        [b],
        b.status_id == ^Status.get_status_id("driver_assigned") and (b.sms_sent == false or b.whatsapp_sent == false)
      )
      |> Repo.all()
      |> Enum.each(fn booking -> BookingRequest.send_message(BookingRequest.get_booking_request(booking.id)) end)
    end
  end

  def get_locality_from_lat_lng(lat, lng) do
    try do
      address_map = (ExternalApiHelper.get_address_from_lat_lng(lat, lng) |> List.first() || %{}) |> Map.get("address_components")

      if not is_nil(address_map) do
        sublocality_level_1 =
          address_map |> Enum.filter(fn comp -> Enum.member?(comp["types"], "sublocality_level_1") end) |> List.last() ||
            %{}

        sublocality_level_2 =
          address_map |> Enum.filter(fn comp -> Enum.member?(comp["types"], "sublocality_level_2") end) |> List.last() ||
            %{}

        sublocality = address_map |> Enum.filter(fn comp -> Enum.member?(comp["types"], "sublocality") end) |> List.last() || %{}

        locality = address_map |> Enum.filter(fn comp -> Enum.member?(comp["types"], "locality") end) |> List.last() || %{}

        {sublocality_level_1["long_name"] || sublocality_level_2["long_name"] || sublocality["long_name"] ||
           locality["long_name"], locality["long_name"] || sublocality["long_name"] || sublocality_level_2["long_name"]}
      else
        {nil, nil}
      end
    rescue
      _ ->
        {nil, nil}
    end
  end

  def repopulate_locality_info(booking_request) do
    {sub_locality, locality} = BookingRequest.get_locality_from_lat_lng(booking_request.latitude, booking_request.longitude)

    BookingRequest.changeset(booking_request, %{"sub_locality" => sub_locality, "locality" => locality})
    |> Repo.update!()
  end

  def validate_vehicle_assignment(changeset) do
    case changeset.valid? do
      true ->
        cab_vehicle_id = get_field(changeset, :cab_vehicle_id)
        id = get_field(changeset, :id)

        if not is_nil(id) and not is_nil(changeset.changes[:cab_vehicle_id]) do
          assignedBooking =
            BookingRequest
            |> where(
              [b],
              b.cab_vehicle_id == ^cab_vehicle_id and b.id != ^id and
                b.status_id == ^Status.get_status_id("driver_assigned")
            )
            |> Repo.all()
            |> List.last()

          if not is_nil(assignedBooking) do
            add_error(changeset, :cab_vehicle_id, "Vehicle already assigned to booking id #{assignedBooking.id}")
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

  def validate_vehicle_city(changeset) do
    case changeset.valid? do
      true ->
        cab_vehicle_id = get_field(changeset, :cab_vehicle_id)
        id = get_field(changeset, :id)

        if not is_nil(id) and not is_nil(changeset.changes[:cab_vehicle_id]) do
          vehicle = Repo.get(Vehicle, cab_vehicle_id)
          booking_request = Repo.get(BookingRequest, id)

          if vehicle.city_id != booking_request.city_id do
            add_error(changeset, :cab_vehicle_id, "Vehicle and booking belong to different city")
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

  def validate_delete_booking_request(changeset) do
    case changeset.valid? do
      true ->
        id = get_field(changeset, :id)

        if not is_nil(id) and not is_nil(changeset.changes[:status_id]) and
             changeset.changes[:status_id] == Status.get_status_id("deleted") do
          booking_request = Repo.get(BookingRequest, id)
          pickup_time = booking_request.pickup_time
          now = NaiveDateTime.utc_now()

          if now >= pickup_time do
            add_error(changeset, :status_id, "Booking cannot be cancelled after pickup time")
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

  def update_booking_req_for_deduping!(lead, deduped_client_name, city_id) do
    if city_id === nil do
      BookingRequest.changeset(lead, %{
        client_name: deduped_client_name
      })
    else
      ch =
        BookingRequest.changeset(lead, %{
          client_name: deduped_client_name,
          city_id: city_id
        })

      Repo.update!(ch)
    end
  end
end
