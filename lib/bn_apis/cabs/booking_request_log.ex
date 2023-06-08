defmodule BnApis.Cabs.BookingRequestLog do
  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query
  alias BnApis.Cabs.BookingRequest
  alias BnApis.Cabs.BookingRequestLog
  alias BnApis.Repo
  alias BnApis.Accounts.EmployeeCredential
  alias BnApis.Organizations.Broker

  schema "cab_booking_request_logs" do
    field :changes, :map
    field :user_id, :integer
    field :user_type, :string
    belongs_to(:cab_booking_request, BookingRequest)
    timestamps()
  end

  @required [:cab_booking_request_id, :user_type, :changes]
  @optional [:user_id]

  @doc false
  def changeset(cab_booking_request_log, attrs) do
    cab_booking_request_log
    |> cast(attrs, @required ++ @optional)
    |> validate_required(@required)
    |> foreign_key_constraint(:cab_booking_request_id)
  end

  def create!(params) do
    %BookingRequestLog{}
    |> BookingRequestLog.changeset(params)
    |> Repo.insert!()
  end

  def update!(cab_booking_request_log, params) do
    cab_booking_request_log
    |> BookingRequestLog.changeset(params)
    |> Repo.update!()
  end

  def log(booking_request, user_id, user_type, changeset) do
    params = %{
      "user_id" => user_id,
      "user_type" => user_type,
      "cab_booking_request_id" => booking_request.id,
      "changes" => changeset.changes
    }

    %BookingRequestLog{}
    |> BookingRequestLog.changeset(params)
    |> Repo.insert!()
  end

  def get_logs_for_booking_request(booking_request_id, page) do
    cab_booking_request_id = if is_binary(booking_request_id), do: String.to_integer(booking_request_id), else: booking_request_id

    page_no = if is_binary(page), do: String.to_integer(page), else: page
    limit = 20
    offset = (page_no - 1) * limit

    booking_request_logs =
      BookingRequestLog
      |> where([br], br.cab_booking_request_id == ^cab_booking_request_id)
      |> offset(^offset)
      |> limit(^limit)
      |> order_by([br], desc: br.inserted_at)
      |> Repo.all()

    booking_request_logs =
      booking_request_logs
      |> Enum.map(fn brl ->
        user_details =
          cond do
            brl.user_type == "broker" ->
              broker_details =
                Broker.fetch_broker_from_ids([brl.user_id])
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

              broker_details

            brl.user_type == "employee" ->
              user = Repo.get_by(EmployeeCredential, id: brl.user_id)

              %{
                "id" => user.id,
                "name" => user.name,
                "phone_number" => user.phone_number
              }

            true ->
              %{}
          end

        user_data =
          if not is_nil(user_details) do
            %{
              "id" => user_details["id"],
              "name" => user_details["name"],
              "phone_number" => user_details["phone_number"]
            }
          else
            %{}
          end

        %{
          "id" => brl.id,
          "cab_booking_request_id" => brl.cab_booking_request_id,
          "user_id" => brl.user_id,
          "user_type" => brl.user_type,
          "user_details" => user_data,
          "changes" => brl.changes,
          "inserted_at" => brl.inserted_at
        }
      end)

    %{
      "booking_request_logs" => booking_request_logs,
      "next_page_exists" => Enum.count(booking_request_logs) >= limit,
      "next_page_query_params" => "page=#{page_no + 1}"
    }
  end
end
