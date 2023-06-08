defmodule BnApis.Repo.Migrations.AddWhatsappWebhookFields do
  use Ecto.Migration

  def change do
    alter table(:whatsapp_webhooks) do
      add :content_type, :string
      add :button_response, :map
    end
  end
end
