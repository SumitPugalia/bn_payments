defmodule BnApis.Repo.Migrations.CreateCommercialChannelUrlMapping do
  use Ecto.Migration

  def change do
    create table(:commercial_channel_url_mapping) do
      add :is_active, :boolean, default: true
      add :channel_url, :string
      add :commercial_property_post_id, references(:commercial_property_posts)
      add :broker_id, references(:brokers)
      timestamps()
    end
  end
end
