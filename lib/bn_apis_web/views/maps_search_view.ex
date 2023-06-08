defmodule BnApisWeb.MapsSearchView do
  use BnApisWeb, :view

  def render("place_details.json", %{place_details: place_details}) do
    %{
      display_address: place_details.display_address,
      latitude: place_details.latitude,
      longitude: place_details.longitude,
      name: place_details.name,
      place_key: place_details.place_key
    }
  end
end
