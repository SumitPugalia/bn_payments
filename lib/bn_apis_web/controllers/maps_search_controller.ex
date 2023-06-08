defmodule BnApisWeb.MapsSearchController do
  use BnApisWeb, :controller
  alias BnApis.Helpers.GoogleMapsHelper
  alias BnApisWeb.MapsSearchView
  alias BnApis.Helpers.ExternalApiHelper

  def fetch_place_details(conn, %{"place_id" => place_id, "google_session_token" => google_session_token}) do
    case GoogleMapsHelper.fetch_place_details(place_id, google_session_token) do
      nil ->
        conn |> put_status(:unprocessable_entity) |> json(%{message: "Place not found"})

      place_details ->
        conn
        |> put_status(:ok)
        |> render(MapsSearchView, "place_details.json", place_details: place_details)
    end
  end

  def fetch_addess(conn, %{"latitude" => lat, "longitude" => lng}) do
    response = ExternalApiHelper.get_formatted_address_from_lat_lng(lat, lng)

    conn
    |> put_status(:ok)
    |> json(response)
  end
end
