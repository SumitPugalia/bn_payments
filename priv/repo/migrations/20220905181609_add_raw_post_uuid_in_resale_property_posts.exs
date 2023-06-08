defmodule BnApis.Repo.Migrations.AddRawPostUuidInResalePropertyPosts do
  use Ecto.Migration

  def change do
    alter table(:resale_property_posts) do
      add(:raw_post_uuid, :string)
    end
  end
end
