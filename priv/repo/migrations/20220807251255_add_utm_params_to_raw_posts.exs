defmodule BnApis.Repo.Migrations.AddUtmParamsToRawPosts do
  use Ecto.Migration

  def change do
    alter table(:raw_rental_property_posts) do
      add(:utm_source, :string)
      add(:utm_medium, :string)
      add(:utm_campaign, :string)
      add(:gclid, :string)
      add(:fbclid, :string)
      add(:utm_map, :jsonb)
    end

    alter table(:raw_resale_property_posts) do
      add(:utm_source, :string)
      add(:utm_medium, :string)
      add(:utm_campaign, :string)
      add(:gclid, :string)
      add(:fbclid, :string)
      add(:utm_map, :jsonb)
    end
  end
end
