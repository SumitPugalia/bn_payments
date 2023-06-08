defmodule BnApis.Repo.Migrations.AddBuildingIdRawPostsTable do
  use Ecto.Migration

  def change do
    alter table(:raw_rental_property_posts) do
      add :building_uuid, :uuid, null: true
    end

    alter table(:raw_resale_property_posts) do
      add :building_uuid, :uuid, null: true
    end
  end
end
