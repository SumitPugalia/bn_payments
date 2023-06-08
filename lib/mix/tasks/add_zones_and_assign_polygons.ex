defmodule Mix.Tasks.AddZonesAndAssignPolygons do
  import Ecto.Query

  use Mix.Task
  alias BnApis.Places.Polygon
  alias BnApis.Places.Zone

  alias BnApis.Repo

  def run(_) do
    Mix.Task.run("app.start", [])

    # Marking all polygons as active true
    Polygon
    |> Repo.update_all(set: [is_active: true])

    IO.inspect("All existing polygons are active")

    # Below polygon names are to be rectified as they contain extra spaces
    from(p in Polygon,
      where: p.name != "Mumbai Central ",
      update: [set: [name: fragment("trim(?)", p.name)]]
    )
    |> Repo.update_all([])

    # Marking all zones as active false
    Zone
    |> Repo.update_all(set: [is_active: false])

    IO.inspect("All existing zones are deactivated")

    # Creating Zones
    File.stream!("#{File.cwd!()}/priv/data/zones.csv")
    |> CSV.decode()
    |> Enum.to_list()
    |> Enum.map(&create_zone_struct/1)
    |> Enum.reject(&is_nil/1)
    |> (&Repo.insert_all(Zone, &1, on_conflict: :nothing)).()

    IO.inspect("All new zones are created")

    # Zone name-id mapping
    zone_name_id_map =
      Zone
      |> select([z], {z.name, z.id})
      |> Repo.all()
      |> Enum.reduce(%{}, fn x, acc -> Map.put(acc, elem(x, 0), elem(x, 1)) end)

    # Contains name, id map for Mumbai, Pune and Bangalore - Have cross checked for name to be unique for these cities
    polygon_name_id_map =
      Polygon
      |> where([p], p.city_id in [1, 2, 37])
      |> select([p], {p.name, p.id})
      |> Repo.all()
      |> Enum.reduce(%{}, fn x, acc -> Map.put(acc, elem(x, 0), elem(x, 1)) end)

    File.stream!("#{File.cwd!()}/priv/data/attach_polygons_to_zones.csv")
    |> CSV.decode(separator: ?;)
    |> Enum.to_list()
    |> Enum.map(fn x -> fetch_polygon_and_zone(x, zone_name_id_map, polygon_name_id_map) end)
    |> Enum.reduce(%{}, fn {zone_id, polygon_id}, acc ->
      polygon_ids = Map.get(acc, zone_id, [])
      Map.put(acc, zone_id, polygon_ids ++ [polygon_id])
    end)
    |> Enum.each(fn {zone_id, polygon_ids} ->
      Polygon
      |> where([p], p.id in ^polygon_ids and p.is_active == ^true)
      |> Repo.update_all(set: [zone_id: zone_id])
    end)
  end

  def create_zone_struct({:error, data}) do
    IO.inspect("Error: #{data}")
    nil
  end

  def create_zone_struct({:ok, data}) do
    %{
      city_id: data |> Enum.at(0) |> String.trim() |> String.to_integer(),
      name: data |> Enum.at(1) |> String.trim(),
      is_active: true,
      inserted_at: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second),
      updated_at: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)
    }
  end

  def fetch_polygon_and_zone({:error, data}, _zone_name_id_map, _polygon_name_id_map) do
    IO.inspect("Error: #{data}")
    nil
  end

  def fetch_polygon_and_zone({:ok, data}, zone_name_id_map, polygon_name_id_map) do
    zone_name = data |> Enum.at(0) |> String.trim()
    polygon_name = data |> Enum.at(1)
    if is_nil(polygon_name_id_map[polygon_name]), do: IO.inspect(polygon_name)
    if is_nil(zone_name_id_map[zone_name]), do: IO.inspect(zone_name)
    {zone_name_id_map[zone_name], polygon_name_id_map[polygon_name]}
  end
end
