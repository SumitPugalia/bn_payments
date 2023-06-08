defmodule BnApisWeb.V1.BuildingController do
  use BnApisWeb, :controller

  alias BnApis.Buildings
  alias BnApis.Buildings.Building
  alias BnApis.Helpers.{Connection, ApplicationHelper}
  alias BnApisWeb.Helpers.BuildingHelper
  alias BnApis.Posts.PostType
  alias BnApis.Places.Polygon

  action_fallback BnApisWeb.FallbackController

  @doc """
    Requires Session
    To be used for user autocomplete from buildings
  """

  def search_buildings(conn, %{"q" => search_text}) do
    search_buildings(conn, search_text)
  end

  def search_buildings(conn, %{"q" => search_text, "exclude_building_uuids" => exclude_building_uuids}) do
    search_buildings(conn, search_text, exclude_building_uuids)
  end

  def search_buildings(conn, %{
        "q" => search_text,
        "exclude_building_uuids" => exclude_building_uuids,
        "type_id" => type_id
      }) do
    search_buildings(conn, search_text, exclude_building_uuids, type_id)
  end

  def search_buildings(conn, search_text, exclude_building_uuids \\ "", type_id \\ 1) do
    logged_in_user = Connection.get_logged_in_user(conn)
    city_id = logged_in_user.operating_city || ApplicationHelper.get_pune_city_id()
    search_text = search_text |> String.downcase()
    exclude_building_uuids = if exclude_building_uuids == "", do: [], else: exclude_building_uuids |> String.split(",")
    type_id = if not is_nil(type_id) and type_id |> is_binary(), do: String.to_integer(type_id), else: type_id || 1
    suggestions = Task.async(fn -> get_building_suggestions(search_text, exclude_building_uuids, city_id, type_id) end)

    similar_suggestions = Task.async(fn -> get_similar_building_suggestions(search_text, exclude_building_uuids, city_id, type_id) end)

    conn
    |> put_status(:ok)
    |> json(%{suggestions: Task.await(suggestions), similar_suggestions: Task.await(similar_suggestions)})
  end

  def landmark_suggestions(conn, params) do
    logged_in_user = Connection.get_logged_in_user(conn)
    operating_city = logged_in_user.operating_city || ApplicationHelper.get_pune_city_id()
    {filters, geom} = params |> BuildingHelper.process_suggestions_params()
    type_id = params["type_id"]
    type_id = if not is_nil(type_id) and type_id |> is_binary(), do: String.to_integer(type_id), else: type_id || 1

    suggestions =
      Task.async(fn ->
        Buildings.fetch_matching_buildings(
          params["post_type"],
          filters,
          geom,
          operating_city,
          params["building_type_ids"] || [1]
        )
      end)

    nearby_suggestions =
      Task.async(fn ->
        Buildings.fetch_nearby_buildings(geom, operating_city, type_id, filters["exclude_building_ids"])
      end)

    suggestions = Task.await(suggestions) |> Buildings.limit_landmark_building_suggestions()
    nearby_suggestions = Task.await(nearby_suggestions) |> Buildings.limit_landmark_building_suggestions()

    conn
    |> put_status(:ok)
    |> json(%{suggestions: suggestions, similar_suggestions: nearby_suggestions})
  end

  def building_suggestions(conn, %{"building_id" => building_id} = params) do
    logged_in_user = Connection.get_logged_in_user(conn)
    operating_city = logged_in_user.operating_city || ApplicationHelper.get_pune_city_id()

    with building when not is_nil(building) <- BnApis.Repo.get_by(Building, %{uuid: building_id}),
         buildings <-
           Buildings.fetch_matching_buildings(
             params["post_type"] |> to_integer() |> PostType.get_by_id() |> Map.get(:name) |> String.downcase(),
             params,
             building.location.coordinates,
             operating_city,
             params["building_type_ids"] || [1]
           ),
         suggestions <- Polygon.parse_building_searches(buildings) do
      conn
      |> put_status(:ok)
      |> json(%{suggestions: suggestions})
    else
      nil -> {:error, "invalid building uuid"}
    end
  end

  ## Private functions
  defp get_building_suggestions(search_text, exclude_building_uuids, city_id, type_id) do
    Buildings.get_search_suggestions(search_text, exclude_building_uuids, city_id, type_id)
  end

  defp get_similar_building_suggestions(search_text, exclude_building_uuids, city_id, type_id) do
    Buildings.get_similar_buildings(search_text, exclude_building_uuids, city_id, type_id)
  end

  defp to_integer(value) when is_binary(value), do: String.to_integer(value)
  defp to_integer(value) when is_integer(value), do: value
  defp to_integer(_), do: 1
end
