defmodule BnApis.Notifications.Request do
  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query

  alias BnApis.Notifications.Request
  alias BnApisWeb.Helpers.NotificationHelper
  alias BnApis.Repo

  @polling_types ["NEW_STORY_ALERT", "WEB_ALERT"]

  schema "notification_requests" do
    # this is a credential user id
    field :sent_to, :integer
    field :type, :string
    field :payload, :map
    field :notif_payload, :map
    field :response, :map
    field :fcm_id, :string
    field :request_uuid, Ecto.UUID, read_after_writes: true
    field :client_delivered, :boolean

    timestamps()
  end

  @required [:sent_to, :type, :fcm_id]
  @fields @required ++ [:payload, :response, :client_delivered, :notif_payload]

  @doc false
  def changeset(notification_request, attrs) do
    notification_request
    |> cast(attrs, @fields)
    |> validate_required(@required)
    |> foreign_key_constraint(:sent_to)
  end

  def get_notification_request(id) do
    Repo.get(Request, id)
  end

  def update_notification_request(id, params) do
    get_notification_request(id) |> Repo.update(params)
  end

  def create_request(params) do
    %Request{} |> Request.changeset(params) |> Repo.insert!()
  end

  def create_params(broker_id, data, fcm_id, payload) do
    %{
      sent_to: broker_id,
      type: data[:type],
      payload: data,
      notif_payload: payload,
      fcm_id: fcm_id,
      client_delivered: false
    }
  end

  def modify_notif_data(request, data) do
    data
    |> Map.merge(%{
      request_uuid: request.request_uuid
    })
  end

  def update_notif_response(request, notif) do
    response = %{
      status: notif.status,
      message: inspect(notif.response)
    }

    request
    |> change(response: response)
    |> Repo.update!()
  end

  def get_request_from_uuids(uuids) do
    Request
    |> where([r], r.request_uuid in ^uuids)
    |> Repo.all()
  end

  @doc """
    1. returns count of notification requests for a broker
    2. From 9 AM to 9 PM
  """
  def get_notification_count(broker_id, type) do
    {start_date, end_date} = NotificationHelper.get_allowed_notification_send_time()

    Request
    |> where([r], r.sent_to == ^broker_id and r.type == ^type)
    |> where([r], r.inserted_at > ^start_date and r.inserted_at < ^end_date)
    |> select([r], count(r.id))
    |> Repo.one()
  end

  def get_latest_notif(user_id, type, response_message_type) do
    type = "%" <> type <> "%"
    response_message_type = "%" <> response_message_type <> "%"

    Request
    |> where([r], r.sent_to == ^user_id and ilike(r.type, ^type))
    |> where([r], fragment("?->>'message' ilike ?", r.response, ^response_message_type))
    |> order_by(desc: :id)
    |> limit(1)
    |> Repo.one()
  end

  def get_undelivered_notification_requests(user_id) do
    Request
    |> where([r], r.sent_to == ^user_id and r.client_delivered == false)
    |> where([r], r.type in ^@polling_types)
    |> Repo.all()
  end

  def update_client_delivered_flag(request) do
    request
    |> change(client_delivered: true)
    |> Repo.update()
  end
end
