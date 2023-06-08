defmodule BnApis.GoogleMaps.Schema.PlaceDetail do
  use Ecto.Schema
  import Ecto.Changeset

  schema "place_details" do
    field :place_key, :string
    field :name, :string
    field :display_address, :string
    field :location, Geo.PostGIS.Geometry
    field :last_refreshed_at, :integer
    field :address_components, {:array, :map}
    timestamps()
  end

  @fields [:place_key, :name, :display_address, :location, :last_refreshed_at, :address_components]
  @doc false
  def changeset(feedback, attrs) do
    feedback
    |> cast(attrs, @fields)
    |> validate_required(@fields)
    |> unique_constraint(:place_key,
      name: :unique_place_key_for_place_details_index,
      message: "An entry already exist with the given place_key"
    )
  end
end
