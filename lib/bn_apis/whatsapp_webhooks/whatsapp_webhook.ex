defmodule BnApis.WhatsappWebhooks.WhatsappWebhook do
  use Ecto.Schema
  import Ecto.Changeset

  schema "whatsapp_webhooks" do
    field :channel, :string
    field :app_details, :map
    field :events, :map
    field :event_content, :map
    field :content_type, :string
    field :button_response, :map
    timestamps()
  end

  @fields [:channel, :app_details, :events, :event_content, :content_type, :button_response]

  @doc false
  def changeset(whatsapp_webhook, attrs) do
    whatsapp_webhook
    |> cast(attrs, @fields)
  end
end
