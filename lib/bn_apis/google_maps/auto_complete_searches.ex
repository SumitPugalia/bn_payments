defmodule BnApis.GoogleMaps.AutoCompleteSearches do
  import Ecto.Query
  alias BnApis.Repo
  alias BnApis.GoogleMaps.Schema.AutoCompleteSearch

  def get_autocomplete_search_results(search_text, language, components, location_restriction) do
    autocomplete_search = fetch_autocomplete_search(search_text, language, components, location_restriction)

    case autocomplete_search do
      nil -> {nil, nil}
      _ -> {autocomplete_search.search_results, autocomplete_search.last_refreshed_at}
    end
  end

  def fetch_autocomplete_search(search_text, language, components, location_restriction) do
    AutoCompleteSearch
    |> where([a], a.search_text == ^search_text and a.language == ^language and a.components == ^components and a.location_restriction == ^location_restriction)
    |> Repo.one()
  end

  def create_or_update_autocomplete_search(search_text, language, components, location_restriction, formatted_results) do
    autocomplete_search = fetch_autocomplete_search(search_text, language, components, location_restriction)

    case autocomplete_search do
      nil ->
        create_autocomplete_search(search_text, language, components, location_restriction, formatted_results)

      autocomplete_search ->
        update_autocomplete_search(autocomplete_search, formatted_results)
    end
  end

  def create_autocomplete_search(search_text, language, components, location_restriction, formatted_results) do
    autocomplete_search_params = create_autocomplete_search_params(search_text, language, components, location_restriction, formatted_results)
    changeset = AutoCompleteSearch.changeset(%AutoCompleteSearch{}, autocomplete_search_params)
    Repo.insert(changeset)
  end

  def update_autocomplete_search(autocomplete_search, formatted_results) do
    params_to_update = %{"search_results" => formatted_results, "last_refreshed_at" => DateTime.to_unix(DateTime.utc_now())}
    changeset = AutoCompleteSearch.changeset(autocomplete_search, params_to_update)
    Repo.update(changeset)
  end

  def create_autocomplete_search_params(search_text, language, components, location_restriction, formatted_results) do
    %{
      search_text: search_text,
      language: language,
      components: components,
      location_restriction: location_restriction,
      last_refreshed_at: DateTime.to_unix(DateTime.utc_now()),
      search_results: formatted_results
    }
  end
end
