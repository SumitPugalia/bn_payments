defmodule BnApis.Repo.Migrations.CreateWhatsappWebhook do
  use Ecto.Migration

  def change do
    create table(:whatsapp_webhooks) do
      add :channel, :string
      add :app_details, :map
      add :events, :map
      add :event_content, :map
      timestamps()
    end
  end
end
