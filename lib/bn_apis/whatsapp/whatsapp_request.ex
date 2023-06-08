defmodule BnApis.Whatsapp.WhatsappRequest do
  use Ecto.Schema
  import Ecto.Changeset

  alias BnApis.Repo
  alias BnApis.Whatsapp.WhatsappRequest

  import Ecto.Query

  schema "whatsapp_requests" do
    field :to, :string
    field :status, :string
    field :template, :string
    field :status_code, :string
    field :status_desc, :string
    field :message_sid, :string
    field :template_vars, {:array, :string}, default: []
    field :customer_ref, :string
    field :message_tag, :string
    field :conversation_id, :string
    field :entity_type, :string
    field :entity_id, :integer

    timestamps()
  end

  @required [:to, :status, :template, :template_vars]
  @fields @required ++
            [
              :customer_ref,
              :message_tag,
              :conversation_id,
              :status_code,
              :status_desc,
              :message_sid,
              :entity_type,
              :entity_id
            ]

  @deliver_msg_statuses ["delivered", "read"]
  @created_status "created"
  @not_sent_status "Not Sent"

  def not_sent_status() do
    @not_sent_status
  end

  @doc false
  def changeset(whatsapp_request, attrs) do
    whatsapp_request
    |> cast(attrs, @fields)
    |> validate_required(@required)
  end

  @doc """
  1. Create a new record with the given params if it does not exist
  2. Updates in case record exists
  """
  def create_or_update_whatsapp_request(params) do
    case fetch_whatsapp_request(params["message_sid"]) do
      nil -> %WhatsappRequest{}
      whatsapp_request -> whatsapp_request
    end
    |> WhatsappRequest.changeset(params)
    |> Repo.insert_or_update()
  end

  def fetch_whatsapp_request(message_sid) do
    Repo.get_by(WhatsappRequest, message_sid: message_sid)
  end

  def create_whatsapp_request(to, template, vars \\ [], opts \\ %{}) do
    customer_ref = opts["customer_ref"]
    message_tag = opts["message_tag"]
    conversation_id = opts["conversation_id"]
    entity_type = opts["entity_type"]
    entity_id = opts["entity_id"]

    params = %{
      "to" => to,
      "status" => @created_status,
      "template" => template,
      "template_vars" => vars,
      "customer_ref" => customer_ref,
      "message_tag" => message_tag,
      "conversation_id" => conversation_id,
      "entity_type" => entity_type,
      "entity_id" => entity_id
    }

    %WhatsappRequest{} |> WhatsappRequest.changeset(params) |> Repo.insert!()
  end

  def list_of_entity_ids_for_delivered_messages(entity_type) do
    WhatsappRequest
    |> where([wr], wr.entity_type == ^entity_type and wr.status in ^@deliver_msg_statuses)
    |> select([wr], wr.entity_id)
    |> Repo.all()
  end
end
