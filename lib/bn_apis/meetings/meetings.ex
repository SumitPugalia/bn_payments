defmodule BnApis.Meetings do
  import Ecto.Query
  alias BnApis.Meetings.Schema.Meetings
  alias BnApis.Repo
  alias BnApis.Helpers.ExternalApiHelper
  alias BnApis.Helpers.ApplicationHelper
  alias BnApis.Helpers.S3Helper
  alias BnApis.Helpers.Redis
  alias BnApis.Accounts.Credential
  alias BnApis.Helpers.Time

  # in seconds
  @qr_code_validity 30
  @qr_redis_key "qr_code_details"
  @qr_redis_key_separator "_separator_"
  @distance_range 500

  alias BnApis.Organizations.Broker

  def get_meeting_by_id(meeting_id), do: Repo.get_by(Meetings, id: meeting_id)

  def get_meetings(page_no, id, filter_date, limit) do
    offset = (page_no - 1) * limit

    query =
      Meetings
      |> where([m], m.employee_credentials_id == ^id and m.active == true)
      |> limit(^limit)
      |> offset(^offset)

    filter_date =
      if !is_nil(filter_date) do
        DateTime.from_unix!(filter_date) |> Timex.to_datetime("Asia/Kolkata") |> NaiveDateTime.to_date()
      end

    query =
      if !is_nil(filter_date) do
        query |> where([m], fragment("timezone('asia/kolkata', timezone('utc', ?))::date", m.inserted_at) == ^filter_date)
      else
        query
      end

    meetings =
      query
      |> Repo.all()
      |> Enum.map(fn meeting ->
        broker_details = Broker.get_broker_details(meeting.broker_id)

        %{
          "meeting_id" => meeting.id,
          "latitude" => meeting.latitude,
          "longitude" => meeting.longitude,
          "notes" => meeting.notes,
          "broker_details" => broker_details,
          "address" => meeting.address,
          "meeting_date" => meeting.inserted_at |> Time.naive_to_epoch()
        }
      end)

    result = %{
      "meetings" => meetings,
      "next_page_exists" => Enum.count(meetings) >= limit,
      "next_page_query_params" => "p=#{page_no + 1}"
    }

    {:ok, result}
  end

  def create_meeting(lat, lng, notes, broker_id, employee_id) do
    address = (ExternalApiHelper.get_address_from_lat_lng(lat, lng) |> List.first() || %{}) |> Map.get("formatted_address")

    Meetings.changeset(%Meetings{}, %{
      latitude: lat,
      longitude: lng,
      notes: notes,
      broker_id: broker_id,
      employee_credentials_id: employee_id,
      address: address,
      active: true
    })
    |> Repo.insert()
  end

  def update_meeting(params, meeting) do
    changeset = Meetings.changeset(meeting, params)
    Repo.update(changeset)
  end

  def save_lat_long_and_generate_qr(latitude, longitude, broker_uuid) do
    secret_key = Ecto.UUID.generate()

    save_lat_long_in_cache(latitude, longitude, secret_key, broker_uuid)

    qr_code_content = "#{secret_key}#{@qr_redis_key_separator}#{broker_uuid}"

    image =
      qr_code_content
      |> QRCodeEx.encode()
      |> QRCodeEx.png()

    # save image in s3
    key = "qr_code/#{secret_key}_#{broker_uuid}.png"
    files_bucket = ApplicationHelper.get_files_bucket()
    {:ok, _message} = S3Helper.put_file(files_bucket, key, image)

    {:ok, %{"image_url" => S3Helper.get_imgix_url(key), "qr_code_validity" => @qr_code_validity}}
  end

  defp save_lat_long_in_cache(latitude, longitude, secret_key, broker_uuid) do
    key = "#{@qr_redis_key}_#{broker_uuid}"
    Redis.q(["HSET", key, "longitude", longitude])
    Redis.q(["HSET", key, "latitude", latitude])
    Redis.q(["HSET", key, "secret_key", secret_key])

    Redis.q(["EXPIRE", key, @qr_code_validity])
  end

  def verify_qr_code(agent_latitude, agent_longitude, broker_uuid, secret_key) do
    key = "#{@qr_redis_key}_#{broker_uuid}"
    {:ok, broker_latitude} = Redis.q(["HGET", key, "latitude"])
    {:ok, broker_longitude} = Redis.q(["HGET", key, "longitude"])
    broker_secret_key = Redis.q(["HGET", key, "secret_key"])

    case broker_secret_key do
      {_ok, nil} ->
        {:qr_code_error,
         %{
           "message" => "QR code validity expired",
           "distance_range" => @distance_range
         }}

      {:ok, broker_secret_key} ->
        broker_latitude = broker_latitude |> String.to_float()
        broker_longitude = broker_longitude |> String.to_float()

        if broker_secret_key == secret_key do
          distance = Distance.GreatCircle.distance({agent_longitude, agent_latitude}, {broker_longitude, broker_latitude})
          broker_id = Credential.get_broker_id_from_uuid(broker_uuid)
          broker_details = Broker.get_broker_details(broker_id)

          if distance < @distance_range do
            {:ok,
             %{
               "message" => "Success",
               "distance" => distance,
               "broker_details" => broker_details,
               "distance_range" => @distance_range
             }}
          else
            {:qr_code_error,
             %{
               "message" => "Please ensure devices are nearby to log the meeting",
               "distance_range" => @distance_range,
               "distance" => distance
             }}
          end
        else
          {:qr_code_error,
           %{
             "message" => "Invalid QR code",
             "distance_range" => @distance_range
           }}
        end
    end
  end
end
