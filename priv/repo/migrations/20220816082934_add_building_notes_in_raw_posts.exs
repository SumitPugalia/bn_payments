defmodule BnApis.Repo.Migrations.AddBuildingNotesInRawPosts do
  use Ecto.Migration

  def change do
    alter table(:raw_rental_property_posts) do
      add(:landmark, :string)
      add(:building_notes, :string)
    end

    alter table(:raw_resale_property_posts) do
      add(:landmark, :string)
      add(:building_notes, :string)
    end
  end
end
