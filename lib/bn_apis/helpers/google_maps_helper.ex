defmodule BnApis.Helpers.GoogleMapsHelper do
  alias BnApis.Helpers.{ExternalApiHelper, ApplicationHelper}
  alias BnApis.GoogleMaps.AutoCompleteSearches
  alias BnApis.GoogleMaps.PlaceDetails
  alias BnApis.Helpers.Utils
  alias BnApis.Helpers.Time

  @expiry_time_in_days 90

  def fetch_autocomplete_place_details(
        search_text,
        iso_country_codes,
        lang_code,
        location_restriction,
        google_session_token
      ) do
    cond do
      is_binary(search_text) and String.length(search_text) >= 3 ->
        get_autocomplete_details(search_text, iso_country_codes, lang_code, location_restriction, google_session_token)

      true ->
        []
    end
  end

  defp get_autocomplete_details(search_text, iso_country_codes, lang_code, location_restriction, google_session_token) do
    country_filter = Enum.join(Enum.map(iso_country_codes, fn country_code -> "country:#{country_code}" end), "|")

    {search_results, last_refreshed_at} = AutoCompleteSearches.get_autocomplete_search_results(search_text, lang_code, country_filter, location_restriction)

    # Checking the latest entry for the autocomplete search and API call will only go if the results stored are there for more than a month.
    if not is_nil(search_results) and not is_nil(last_refreshed_at) and length(search_results) > 0 and
         Time.get_difference_in_days_with_epoch(last_refreshed_at) <= @expiry_time_in_days do
      Enum.map(search_results, fn search_result -> Map.from_struct(search_result) end)
    else
      fetch_autocomplete_api_response(search_text, lang_code, country_filter, google_session_token, location_restriction)
    end
  end

  def fetch_autocomplete_api_response(search_text, lang_code, country_filter, google_session_token, location_restriction) do
    get_details_args = %{
      input: search_text,
      key: get_autocomplete_key(),
      language: lang_code,
      components: country_filter,
      sessiontoken: google_session_token
    }

    get_details_args =
      if not is_nil(location_restriction) and location_restriction != "" do
        get_details_args |> Map.merge(%{locationrestriction: location_restriction})
      else
        get_details_args
      end

    google_autocomplete_api_url =
      get_autocomplete_url() <>
        "?" <> URI.encode_query(get_details_args)

    {status_code, response} = ExternalApiHelper.perform(:post, google_autocomplete_api_url, "", [], [timeout: 3000], true)

    formatted_results =
      case status_code do
        200 -> response["predictions"]
        _ -> []
      end
      |> Enum.map(fn place_info -> format_autocomplete_place_info(place_info) end)
      |> Enum.filter(fn parsed_maps_response -> not is_nil(parsed_maps_response) end)

    Task.async(fn -> AutoCompleteSearches.create_or_update_autocomplete_search(search_text, lang_code, country_filter, location_restriction, formatted_results) end)
    formatted_results
  end

  def format_autocomplete_place_info(place_info) do
    name = get_place_name_from_autocomplete_response(place_info["structured_formatting"])
    place_key = get_place_id_from_autocomplete_response(place_info["place_id"])
    display_address = get_place_address_from_autocomplete_response(place_info["structured_formatting"])

    formatted_data = %{
      name: name,
      place_key: place_key,
      display_address: display_address
    }

    if is_nil(name) or is_nil(place_key) or is_nil(display_address), do: nil, else: formatted_data
  end

  defp get_place_name_from_autocomplete_response(nil), do: nil

  defp get_place_name_from_autocomplete_response(structured_formatting) do
    structured_formatting["main_text"]
  end

  defp get_place_address_from_autocomplete_response(nil), do: nil

  defp get_place_address_from_autocomplete_response(structured_formatting) do
    structured_formatting["secondary_text"]
  end

  defp get_place_id_from_autocomplete_response(nil), do: nil
  defp get_place_id_from_autocomplete_response(place_id), do: place_id

  ## Google Autocomplete API
  def get_autocomplete_url(),
    do:
      :bn_apis
      |> Application.get_env(__MODULE__, [])
      |> Keyword.get(:autocomplete_url, "")

  ## Google Autocomplete API key
  def get_autocomplete_key(), do: ApplicationHelper.get_places_key()

  # Place detail API functions

  def fetch_place_details(google_place_id, google_session_token) do
    {place_details, last_refreshed_at} = PlaceDetails.get_place_details(google_place_id)

    # Checking the latest entry for the place details and API call will only go if the results stored are there for more than a month.
    if not is_nil(place_details) and not is_nil(last_refreshed_at) and Time.get_difference_in_days_with_epoch(last_refreshed_at) <= @expiry_time_in_days do
      Map.from_struct(place_details) |> Utils.geo_location_to_lat_lng()
    else
      get_and_parse_place_info(google_place_id, google_session_token)
    end
  end

  def get_and_parse_place_info(place_id, google_session_token) do
    place_details =
      place_id
      |> get_place_details(google_session_token)
      |> build_place_info()

    if not is_nil(place_details), do: Task.async(fn -> PlaceDetails.create_or_update_place_details(place_id, place_details) end)
    place_details
  end

  def get_place_details(place_id, google_session_token) do
    get_details_args = %{
      placeid: place_id,
      key: ApplicationHelper.get_places_key(),
      sessiontoken: google_session_token,
      fields: "address_component,name,geometry,place_id,type,url,formatted_address"
    }

    google_details_api_url =
      ApplicationHelper.get_places_url() <>
        "?" <> URI.encode_query(get_details_args)

    {status_code, response} = ExternalApiHelper.perform(:get, google_details_api_url, "", [], [timeout: 2000], true)

    if status_code == 200 and response["status"] == "OK", do: response["result"], else: nil
  end

  defp build_place_info(nil), do: nil

  defp build_place_info(place_details) do
    if is_nil(place_details["address_components"]) do
      channel = ApplicationHelper.get_slack_channel()

      ApplicationHelper.notify_on_slack(
        "Google place without address component:
          name -> #{place_details["name"]}
          place_id: #{place_details["place_id"]}
          display_address: #{place_details["formatted_address"]}
        ",
        channel
      )
    end

    {latitude, longitude} = get_place_location(place_details["geometry"])

    %{
      name: place_details["name"],
      place_key: place_details["place_id"],
      display_address: place_details["formatted_address"],
      latitude: latitude,
      longitude: longitude,
      address_components:
        (place_details["address_components"] || [])
        |> Enum.map(fn address_component ->
          %{
            name: address_component["long_name"],
            type: hd(address_component["types"])
          }
        end)
    }
  end

  defp get_place_location(_geometry = %{"location" => location}), do: {location["lat"], location["lng"]}
  defp get_place_location(_geometry), do: nil
end
