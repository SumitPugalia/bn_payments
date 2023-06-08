defmodule BnApis.WhatsappWebhooks do
  @moduledoc """
  The WhatsappWebhooks context.
  """

  import Ecto.Query, warn: false
  alias BnApis.Repo
  alias BnApis.WhatsappWebhooks.WhatsappWebhook

  @doc """
  Returns the list of whatsapp_webhooks.

  ## Examples

      iex> whatsapp_webhooks()
      [%WhatsappWebhook{}, ...]

  """
  def list_whatsapp_webhooks do
    Repo.all(WhatsappWebhook)
  end

  @doc """
  Gets a single whatsapp_webhook.

  Raises `Ecto.NoResultsError` if the Whatsapp webhook does not exist.

  ## Examples

      iex> get_whatsapp_webhook!(123)
      %WhatsappWebhook{}

      iex> get_whatsapp_webhook!(456)
      ** (Ecto.NoResultsError)

  """
  def get_whatsapp_webhook!(id), do: Repo.get!(WhatsappWebhook, id)

  @doc """
  Creates a whatsapp_webhook.

  ## Examples

      iex> create_whatsapp_webhook_row(%{field: value})
      {:ok, %WhatsappWebhook{}}

      iex> create_whatsapp_webhook_row(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_whatsapp_webhook_row(params \\ %{}) do
    event_content = get_whatsapp_webhook_event_content(params["eventContent"])

    ch =
      WhatsappWebhook.changeset(%WhatsappWebhook{}, %{
        channel: params["channel"],
        app_details: params["appDetails"],
        events: params["events"],
        event_content: event_content,
        content_type: get_whatsapp_webhook_content_type(event_content["message"]),
        button_response: get_button_response(event_content["message"])
      })

    Repo.insert!(ch)
  end

  def get_whatsapp_webhook_event_content(nil), do: %{}
  def get_whatsapp_webhook_event_content(event_content), do: event_content

  def get_whatsapp_webhook_content_type(nil), do: nil

  def get_whatsapp_webhook_content_type(event_content_msg) do
    event_content_msg["contentType"]
  end

  def get_button_response(event_content_msg) do
    parse_button_payload(event_content_msg["button"])
  end

  def parse_button_payload(nil), do: nil

  def parse_button_payload(button_response) do
    button_response
    |> Map.merge(%{
      "payload" => get_whatsapp_webhook_button_payload(button_response["payload"])
    })
  end

  def get_whatsapp_webhook_button_payload(nil), do: nil

  def get_whatsapp_webhook_button_payload(binary_payload) do
    binary_payload |> Poison.decode!()
  end
end
