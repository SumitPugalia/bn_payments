defmodule BnApis.Repo.Migrations.AddRawPostUuidInRentalPropertyPosts do
  use Ecto.Migration

  def change do
    alter table(:rental_property_posts) do
      add(:raw_post_uuid, :string)
    end
  end
end
