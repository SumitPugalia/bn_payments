defmodule BnApis.GoogleMaps.PlaceDetails do
  import Ecto.Query
  alias BnApis.Repo
  alias BnApis.GoogleMaps.Schema.PlaceDetail
  alias BnApis.Helpers.Utils

  def get_place_details(place_key) do
    place_details = fetch_place_details(place_key)

    case place_details do
      nil -> {nil, nil}
      _ -> {place_details, place_details.last_refreshed_at}
    end
  end

  def fetch_place_details(place_key) do
    PlaceDetail
    |> where([a], a.place_key == ^place_key)
    |> Repo.one()
  end

  def create_or_update_place_details(place_key, params) do
    place_details = fetch_place_details(place_key)

    case place_details do
      nil ->
        create_place_details(place_key, params)

      place_details ->
        update_place_details(place_details, params)
    end
  end

  def create_place_details(place_key, params) do
    place_details_params = create_place_details_params(place_key, params)
    changeset = PlaceDetail.changeset(%PlaceDetail{}, place_details_params)
    Repo.insert(changeset)
  end

  def update_place_details(place_details, params) do
    place_details_params = create_place_details_params(place_details.place_key, params)
    changeset = PlaceDetail.changeset(place_details, place_details_params)
    Repo.update(changeset)
  end

  def create_place_details_params(
        place_key,
        _params = %{
          latitude: latitude,
          longitude: longitude,
          name: name,
          display_address: display_address,
          address_components: address_components
        }
      ) do
    location = Utils.create_geopoint(%{"latitude" => latitude, "longitude" => longitude})

    %{
      place_key: place_key,
      name: name,
      display_address: display_address,
      location: location,
      address_components: address_components,
      last_refreshed_at: DateTime.to_unix(DateTime.utc_now())
    }
  end
end
