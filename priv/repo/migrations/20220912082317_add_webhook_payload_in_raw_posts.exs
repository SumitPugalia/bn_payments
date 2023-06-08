defmodule BnApis.Repo.Migrations.AddWebhookPayloadInRawPosts do
  use Ecto.Migration

  def change do
    alter table(:raw_rental_property_posts) do
      add(:webhook_payload, :map)
    end

    alter table(:raw_resale_property_posts) do
      add(:webhook_payload, :string)
    end
  end
end
