defmodule BnApis.Repo.Migrations.CreatePlaceDetails do
  use Ecto.Migration

  def change do
    create table(:place_details) do
      add(:place_key, :string, null: false)
      add(:name, :string, null: false)
      add(:display_address, :string, null: false)
      add(:location, :geometry, null: false)
      add(:last_refreshed_at, :integer, null: false)
      add(:address_components, {:array, :map}, default: [])
      timestamps()
    end

    create(
      unique_index(
        :place_details,
        [:place_key],
        name: :unique_place_key_for_place_details_index
      )
    )
  end
end
