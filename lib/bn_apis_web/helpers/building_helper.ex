defmodule BnApisWeb.Helpers.BuildingHelper do
  alias BnApis.Buildings

  def process_geo_params(params) do
    params =
      if is_binary(params["longitude"]) and !String.contains?(params["longitude"], ".") do
        Map.put(params, "longitude", params["longitude"] <> ".0")
      else
        params
      end

    params =
      if is_binary(params["latitude"]) and !String.contains?(params["latitude"], ".") do
        Map.put(params, "latitude", params["latitude"] <> ".0")
      else
        params
      end

    longitude =
      if params["longitude"] |> is_binary(),
        do: String.to_float(params["longitude"]),
        else: params["longitude"]

    latitude =
      if params["latitude"] |> is_binary(),
        do: String.to_float(params["latitude"]),
        else: params["latitude"]

    {longitude, latitude}
  end

  def process_suggestions_params(params) do
    filters = params |> create_filters()

    {longitude, latitude} = params |> process_geo_params()
    geom = {longitude, latitude}
    {filters, geom}
  end

  def create_filters(params) do
    {configuration_type_ids, furnishing_type_ids, floor_type_ids} = {params["configuration_type_ids"], params["furnishing_type_ids"], params["floor_type_ids"]}

    configuration_type_ids =
      if is_nil(configuration_type_ids) or configuration_type_ids == "",
        do: [],
        else:
          configuration_type_ids
          |> Poison.decode!()
          |> Enum.map(&String.to_integer(&1))

    furnishing_type_ids =
      if is_nil(furnishing_type_ids) or furnishing_type_ids == "",
        do: [],
        else:
          furnishing_type_ids
          |> Poison.decode!()
          |> Enum.map(&String.to_integer(&1))

    floor_type_ids =
      if is_nil(floor_type_ids) or floor_type_ids == "",
        do: [],
        else: floor_type_ids |> Poison.decode!() |> Enum.map(&String.to_integer(&1))

    is_bachelor =
      if is_nil(params["is_bachelor"]) or params["is_bachelor"] == "false",
        do: false,
        else: true

    max_budget =
      if is_binary(params["max_budget"]),
        do: String.to_integer(params["max_budget"]),
        else: params["max_budget"]

    min_carpet_area =
      if is_binary(params["min_carpet_area"]),
        do: String.to_integer(params["min_carpet_area"]),
        else: params["min_carpet_area"]

    min_parking =
      if is_binary(params["min_parking"]),
        do: String.to_integer(params["min_parking"]),
        else: params["min_parking"]

    {:ok, exclude_building_ids} =
      if is_nil(params["exclude_building_uuids"]) or
           params["exclude_building_uuids"] == "",
         do: {:ok, []},
         else:
           params["exclude_building_uuids"]
           |> String.split(",")
           |> Buildings.get_ids_from_uids()

    %{
      "configuration_type_ids" => configuration_type_ids,
      "furnishing_type_ids" => furnishing_type_ids,
      "exclude_building_ids" => exclude_building_ids,
      "is_bachelor" => is_bachelor,
      "max_rent" => params["max_rent"],
      "max_budget" => max_budget,
      "floor_type_ids" => floor_type_ids,
      "min_carpet_area" => min_carpet_area,
      "min_parking" => min_parking
    }
  end
end
