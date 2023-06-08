defmodule BnApis.Sms.SmsRequest do
  use Ecto.Schema
  import Ecto.Changeset

  alias BnApis.Repo
  alias BnApis.Sms.SmsRequest
  alias BnApis.Helpers.SmsHelper

  schema "sms_requests" do
    field :message_sid, :string
    field :message_status_id, :integer
    field :to, :string
    field :body, :string

    timestamps()
  end

  @required [:message_sid, :to, :body, :message_status_id]
  @fields @required ++ []

  @doc false
  def changeset(sms_request, attrs) do
    sms_request
    |> cast(attrs, @fields)
    |> validate_required(@required)
  end

  @doc """
  1. Create a new record with the given params if it does not exist
  2. Updates in case record exists
  """
  def create_or_update_sms_request(params) do
    case fetch_sms_request(params["message_sid"]) do
      nil -> %SmsRequest{}
      sms_request -> sms_request
    end
    |> SmsRequest.changeset(params)
    |> Repo.insert_or_update()
  end

  def fetch_sms_request(message_sid) do
    Repo.get_by(SmsRequest, message_sid: message_sid)
  end

  @doc """
  1. Being hit after we get response from SMS service
  """
  def parse_params(request_params) do
    %{
      "message_sid" => request_params["sid"],
      "to" => request_params["to"],
      "body" => request_params["body"],
      "message_status_id" => SmsHelper.get_status_id_by_name(request_params["status"])
    }
  end

  def parse_mobtexting_params(request_params, message) do
    data = request_params["data"] |> List.first() || %{}

    %{
      "message_sid" => data["id"],
      "to" => "+" <> data["mobile"],
      "body" => message,
      "message_status_id" => SmsHelper.get_status_id_by_name(data["status"])
    }
  end
end
