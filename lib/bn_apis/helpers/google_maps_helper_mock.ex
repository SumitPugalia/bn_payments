defmodule BnApis.Helpers.GoogleMapsHelperMock do
  def fetch_place_details("invalid_google_id", _), do: nil
  def fetch_place_details(_, _), do: %{latitude: 19.0522115, longitude: 72.900522}
end
