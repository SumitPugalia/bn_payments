defmodule BnApis.Buildings.Building do
  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query

  alias BnApis.Buildings.Building
  alias BnApis.Repo
  alias BnApis.Places.Polygon
  alias BnApis.Buildings.BuildingEnums
  alias BnApis.Places.Zone
  alias BnApis.Helpers.Utils
  alias BnApis.Places.Locality
  alias BnApis.Places.SubLocality

  @similarity_score 0.3

  # in metres
  @allowed_distance_radius 1000.0
  @srid 4326
  @entity_type "buildings"

  schema "buildings" do
    field :address, :map
    field :display_address, :string
    field :name, :string
    field :remote_id, :integer
    field :uuid, Ecto.UUID, read_after_writes: true
    field :source_type_id, :id
    field :location, Geo.PostGIS.Geometry
    field :type, :string
    field :structure, :string
    field :car_parking_ratio, :string
    field :total_development_size, :integer
    field :grade, :string

    belongs_to :locality, Locality
    belongs_to :sub_locality, SubLocality
    belongs_to :polygon, Polygon

    timestamps()
  end

  @fields [
    :uuid,
    :name,
    :address,
    :display_address,
    :remote_id,
    :location,
    :polygon_id,
    :structure,
    :type,
    :car_parking_ratio,
    :total_development_size,
    :grade
  ]

  @doc false
  def changeset(building, attrs) do
    building
    |> cast(attrs, @fields)
    |> unique_constraint(:name,
      name: :buildings_name_location_type_index,
      message: "Provided Building at the given coordinates exists"
    )
    |> validate_required([:name, :polygon_id, :display_address, :type])
    |> validate_commercial_property()
  end

  def validate_commercial_property(changeset) do
    case changeset.valid? do
      true ->
        building_type = get_field(changeset, :type)

        if not is_nil(building_type) && building_type == BuildingEnums.commercial() do
          validate_required(changeset, [:structure, :car_parking_ratio, :total_development_size, :grade])
        else
          changeset
        end

      _ ->
        changeset
    end
  end

  def changeset(attrs) do
    %__MODULE__{}
    |> changeset(attrs)
  end

  def get_ids_from_uids_query(uids) do
    Building
    |> where([b], b.uuid in ^uids)
  end

  def create_building(attrs) do
    %Building{}
    |> Building.changeset(attrs)
    |> Repo.insert()
  end

  def update_building(building, attrs) do
    building
    |> Building.changeset(attrs)
    |> Repo.update()
  end

  def get_building_names(building_ids) do
    Building
    |> where([b], b.id in ^building_ids)
    |> select([b], b.name)
    |> Repo.all()
  end

  def fetch_building_info(building) do
    building
    |> join(:left, [building, p], z in Zone, on: p.zone_id == z.id)
    |> select(
      [b, p, z],
      %{
        id: b.uuid,
        building_id: b.id,
        name: b.name,
        display_address: b.display_address,
        location: b.location,
        type: b.type,
        structure: b.structure,
        car_parking_ratio: b.car_parking_ratio,
        total_development_size: b.total_development_size,
        grade: b.grade,
        polygon: %{
          id: p.id,
          uuid: p.uuid,
          name: p.name,
          city_id: p.city_id
        }
      }
    )
  end

  def filter_building_by_city_id(buildings, _city_id = nil), do: buildings

  def filter_building_by_city_id(buildings, city_id),
    do: buildings |> where([building, polygon], polygon.city_id == ^city_id)

  def filter_building_by_polygon_id(buildings, _polygon_id = nil), do: buildings

  def filter_building_by_polygon_id(buildings, polygon_id),
    do: buildings |> where([building, polygon], polygon.id == ^polygon_id)

  def filter_building(buildings, search_text \\ nil, exclude_building_uuids \\ nil, type_id \\ nil) do
    buildings =
      if not is_nil(exclude_building_uuids) do
        buildings |> where([building], building.uuid not in ^exclude_building_uuids)
      else
        buildings
      end

    buildings =
      if not is_nil(type_id) do
        building_type = BuildingEnums.building_type_enum()[type_id]["identifier"]
        buildings |> where([building], building.type == ^building_type)
      else
        buildings
      end

    buildings =
      if not is_nil(search_text) and search_text != "" do
        modified_search_text = "%" <> search_text <> "%"
        buildings |> where([building], ilike(building.name, ^modified_search_text))
      else
        buildings
      end

    buildings
  end

  def search_building_query(search_text, exclude_building_uuids, city_id, limit, type_id) do
    buildings =
      filter_building(Building, search_text, exclude_building_uuids, type_id)
      |> join(:inner, [building], p in Polygon, on: building.polygon_id == p.id)
      |> filter_building_by_city_id(city_id)

    buildings
    |> order_by([building, _p], fragment("lower(?) <-> ?", building.name, ^search_text))
    |> limit(^limit)
    |> fetch_building_info()
  end

  defp parse_to_integer_if_binary(field) when not is_nil(field) and is_binary(field) do
    if Integer.parse(field) == :error, do: {nil, nil}, else: Integer.parse(field)
  end

  defp parse_to_integer_if_binary(field), do: {field, nil}

  def admin_search_building_query(search_text, exclude_building_uuids, city_id, limit, polygon_id, type_id) do
    {city_id, _} = parse_to_integer_if_binary(city_id)
    {polygon_id, _} = parse_to_integer_if_binary(polygon_id)

    buildings =
      filter_building(Building, search_text, exclude_building_uuids, type_id)
      |> join(:inner, [building], p in Polygon, on: building.polygon_id == p.id)
      |> filter_building_by_city_id(city_id)
      |> filter_building_by_polygon_id(polygon_id)

    buildings
    |> order_by([building, _p], fragment("lower(?) <-> ?", building.name, ^search_text))
    |> limit(^limit)
    |> fetch_building_info()
  end

  def similar_building_query(search_text, exclude_building_uuids, city_id, limit, type_id) do
    buildings =
      filter_building(Building, nil, exclude_building_uuids, type_id)
      |> join(:inner, [building], p in Polygon, on: building.polygon_id == p.id)
      |> filter_building_by_city_id(city_id)

    buildings =
      if not is_nil(search_text) and search_text != "" do
        buildings
        |> where(
          [building, _p],
          fragment("word_similarity(?, lower(?)) >= ?", ^search_text, building.name, ^@similarity_score)
        )
        |> order_by([building, _p], desc: fragment("word_similarity(?, lower(?))", ^search_text, building.name))
      else
        buildings
        |> order_by([building], asc: building.name)
      end

    buildings
    |> limit(^limit)
    |> fetch_building_info()
  end

  def city_buildings_query(city_id, geom, type_id, exclude_building_ids \\ []) do
    {longitude, latitude} = geom

    filter_building(Building, nil, nil, type_id)
    |> join(:inner, [building], p in Polygon, on: building.polygon_id == p.id)
    |> where([building, p], p.city_id == ^city_id)
    |> where([building, _p], not is_nil(building.location) and building.id not in ^exclude_building_ids)
    |> where(
      [building, _p],
      fragment(
        "ST_DWithin(?::geography, ST_SetSRID(ST_MakePoint(?, ?), ?), ?)",
        building.location,
        ^latitude,
        ^longitude,
        ^@srid,
        ^@allowed_distance_radius
      )
    )
    |> fetch_building_info()
  end

  def calculate_distance(building, pivot_location) do
    building_location = (building[:location] |> Geo.JSON.encode!())["coordinates"] |> List.to_tuple()
    put_in(building, [:distance], Distance.GreatCircle.distance(building_location, pivot_location))
  end

  # 1. returns distance(in meters) between buildings and provided lat long
  # 2. sorted in asc order of distance and filter within allowed distance radius if applicable
  def calculate_distance_and_sort(buildings, geom, distance_filter \\ true, filter_radius \\ @allowed_distance_radius) do
    buildings =
      buildings
      |> Enum.map(&calculate_distance(&1, geom))
      |> Enum.sort_by(& &1[:distance])

    if distance_filter, do: buildings |> Enum.filter(&(&1[:distance] <= filter_radius)), else: buildings
  end

  def get_building_polygon_data(uuids, ids \\ []) do
    Building
    |> join(:inner, [building], p in Polygon, on: building.polygon_id == p.id)
    |> where([building, _p], building.uuid in ^uuids or building.id in ^ids)
    |> select([building, p], %{
      building_id: building.id,
      building_uuid: building.uuid,
      building_name: building.name,
      rent_config_expiry: p.rent_config_expiry,
      resale_config_expiry: p.resale_config_expiry,
      rent_match_parameters: p.rent_match_parameters,
      resale_match_parameters: p.resale_match_parameters
    })
    |> Repo.all()
  end

  def admin_filter_query(params) do
    page_no = Map.get(params, "p", "1") |> String.to_integer()
    size = Map.get(params, "size", "20") |> String.to_integer()

    query =
      Building
      |> join(:left, [b], p in Polygon, on: b.polygon_id == p.id)
      |> where(^filter_building_where_params(params))

    query =
      if not is_nil(params["city_id"]),
        do: query |> where([b, p], p.city_id == ^params["city_id"]),
        else: query

    query =
      if not is_nil(params["polygon_id"]),
        do: query |> where([b, p], p.id == ^params["polygon_id"]),
        else: query

    query =
      if not is_nil(params["building_name"]) do
        building_name = params["building_name"]
        formatted_query = "%#{String.downcase(String.trim(building_name))}%"
        query |> where([b, p], fragment("LOWER(?) LIKE ?", b.name, ^formatted_query))
      else
        query
      end

    content_query =
      query
      |> limit(^size)
      |> offset(^((page_no - 1) * size))

    {query, content_query, page_no, size}
  end

  def filter_building_where_params(filter) do
    Enum.reduce(filter, dynamic(true), fn
      {"type_id", type_id}, dynamic ->
        building_type = get_building_type(type_id)
        dynamic([b, p], ^dynamic and b.type == ^building_type)

      _, dynamic ->
        dynamic
    end)
  end

  def get_building_by_name(nil), do: nil

  def get_building_by_name(building_name) do
    search_query = "%#{String.downcase(building_name)}%"

    Building
    |> where([b], fragment("LOWER(?) LIKE ?", b.name, ^search_query))
    |> Repo.all()
    |> List.first()
  end

  defp get_building_type(type_id) do
    type_id = Utils.parse_to_integer(type_id)
    BuildingEnums.building_type_enum()[type_id]["identifier"]
  end

  def get_entity_type() do
    @entity_type
  end
end
