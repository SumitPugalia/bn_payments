defmodule BnApis.Places.Polygon do
  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query

  alias BnApis.Places.{Polygon, Locality, Zone, City}
  alias BnApis.Repo
  alias BnApisWeb.Helpers.PolygonHelper
  alias BnApis.Helpers.ApplicationHelper
  alias BnApis.Helpers.GoogleMapsHelper
  alias BnApis.Buildings
  alias BnApis.Helpers.Utils
  alias BnApis.Buildings.BuildingEnums

  schema "polygons" do
    field :name, :string
    field :uuid, Ecto.UUID, read_after_writes: true
    field :rent_config_expiry, :map
    field :resale_config_expiry, :map
    field :rent_match_parameters, :map
    field :resale_match_parameters, :map
    field :city_id, :integer
    field :is_active, :boolean, default: true
    field :support_number, :string

    belongs_to :zone, Zone
    belongs_to :locality, Locality
    timestamps()
  end

  @fields [
    :name,
    :rent_config_expiry,
    :resale_config_expiry,
    :rent_match_parameters,
    :resale_match_parameters,
    :city_id,
    :is_active,
    :locality_id,
    :support_number,
    :zone_id
  ]
  @required_fields [
    :name,
    :rent_config_expiry,
    :resale_config_expiry,
    :rent_match_parameters,
    :resale_match_parameters,
    :city_id
  ]

  @doc false
  def changeset(locality, attrs) do
    locality
    |> cast(attrs, @fields)
    |> unique_constraint(:name, name: :polygon_name_city_id_index, message: "Polygon name already exists in this city!")
    |> PolygonHelper.populate_expiry_attrs()
    |> PolygonHelper.populate_base_filters()
    |> PolygonHelper.populate_city()
    |> validate_required(@required_fields)
  end

  def create(attrs) do
    case %Polygon{}
         |> Polygon.changeset(attrs)
         |> Repo.insert() do
      {:ok, polygon} -> {:ok, polygon}
      {:error, changeset} -> {:error, changeset.errors}
    end
  end

  def update(nil, _attrs), do: {:error, "Polygon not found"}

  def update(polygon, attrs) do
    polygon
    |> Polygon.changeset(attrs)
    |> Repo.update()
  end

  def fetch_or_create_polygon(name, city_id \\ ApplicationHelper.get_pune_city_id()) do
    case get_polygon(name) do
      nil ->
        case create(%{name: name, city_id: city_id}) do
          {:ok, polygon} -> polygon
          {:error, errors} -> inspect(errors)
        end

      polygon ->
        polygon
    end
  end

  def fetch_all_polygons_ids(zone_ids) do
    Repo.all(from(p in Polygon, where: p.zone_id in ^zone_ids, select: p.id))
  end

  def get_boolean_val(nil), do: false
  def get_boolean_val(param) when is_binary(param), do: String.trim(param) |> String.downcase() == "true"
  def get_boolean_val(param) when is_boolean(param), do: param

  def search_polygons(search_text, city_id) do
    limit = 30

    query = Polygon

    query =
      if !is_nil(city_id) do
        query |> where([p], p.city_id == ^city_id)
      else
        query
      end

    query =
      if !is_nil(search_text) && is_binary(search_text) && String.trim(search_text) != "" do
        name_query = "%#{String.downcase(search_text)}%"
        query |> where([p], fragment("LOWER(?) LIKE ?", p.name, ^name_query)) |> limit(^limit)
      else
        query
      end

    query
    |> order_by([p], asc: p.name)
    |> select(
      [polygon],
      %{
        id: polygon.id,
        uuid: polygon.uuid,
        name: polygon.name,
        rent_config_expiry: polygon.rent_config_expiry,
        resale_config_expiry: polygon.resale_config_expiry,
        rent_match_parameters: polygon.rent_match_parameters,
        resale_match_parameters: polygon.resale_match_parameters,
        city_id: polygon.city_id,
        zone_id: polygon.zone_id
      }
    )
    |> Repo.all()
  end

  def locality_search(city_id, params) do
    search_text = params["q"]
    add_polygon_searches = Utils.parse_boolean_param(params["add_polygon_searches"])
    polygon_searches = get_parsed_polygon_search_suggestions(add_polygon_searches, search_text, city_id)
    list_of_polygon_names = polygon_searches |> Enum.map(fn x -> String.downcase(String.trim(x.name)) end)
    exclude_building_ids = params["exclude_building_ids"]
    # ToDo: Remove the default building_type_id from 2 to 1 when the force update is done
    type_id =
      Utils.parse_to_integer(params["building_type_id"]) ||
        BuildingEnums.get_building_type_id(BuildingEnums.commercial())

    add_building_searches = Utils.parse_boolean_param(params["add_building_searches"])

    building_searches = get_parsed_building_search_suggestions(add_building_searches, search_text, exclude_building_ids, city_id, type_id)

    add_google_searches = Utils.parse_boolean_param(params["add_google_searches"])
    google_session_token = Map.get(params, "google_session_token", "")
    iso_country_codes = Map.get(params, "iso_country_codes", ["in"])
    lang_code = Map.get(params, "language_code", "en-IN")

    google_searches =
      get_parsed_google_autocomplete_searches(
        add_google_searches,
        search_text,
        city_id,
        iso_country_codes,
        lang_code,
        list_of_polygon_names,
        google_session_token
      )

    %{
      data: polygon_searches,
      buildings: building_searches,
      google_autocomplete_searches: google_searches
    }
  end

  def aggregated_search_results(params, city_id \\ nil) do
    search_results = locality_search(city_id, params)

    if not is_nil(params["building_type_id"]) and Utils.parse_to_integer(params["building_type_id"]) == BuildingEnums.get_building_type_id(BuildingEnums.commercial()) do
      search_results.buildings ++ search_results.data ++ search_results.google_autocomplete_searches
    else
      search_results.data ++ search_results.google_autocomplete_searches ++ search_results.buildings
    end
  end

  def get_parsed_polygon_search_suggestions(false, _search_text, _city_id), do: []

  def get_parsed_polygon_search_suggestions(true, search_text, city_id) do
    search_polygons(search_text, city_id)
    |> parse_polygon_searches()
  end

  def get_parsed_building_search_suggestions(false, _search_text, _exclude_building_ids, _city_id, _type_id), do: []

  def get_parsed_building_search_suggestions(true, search_text, exclude_building_ids, city_id, type_id) do
    Buildings.get_search_suggestions(search_text, exclude_building_ids, city_id, type_id)
    |> parse_building_searches()
  end

  def get_parsed_backward_comptabile_google_autocomplete_searches(
        false,
        _search_text,
        _city_id,
        _iso_country_codes,
        _lang_code,
        _list_of_polygon_names
      ),
      do: []

  def get_parsed_google_autocomplete_searches(
        false,
        _search_text,
        _city_id,
        _iso_country_codes,
        _lang_code,
        _list_of_polygon_names,
        _google_session_token
      ),
      do: []

  def get_parsed_google_autocomplete_searches(
        true,
        search_text,
        city_id,
        iso_country_codes,
        lang_code,
        list_of_polygon_names,
        google_session_token
      ) do
    get_google_autocomplete_searches(search_text, city_id, iso_country_codes, lang_code, google_session_token)
    |> parse_google_autocomplete_searches(list_of_polygon_names)
  end

  def get_google_autocomplete_searches(search_text, city_id, iso_country_codes, lang_code, google_session_token) do
    city = if not is_nil(city_id), do: Repo.get_by(City, id: city_id), else: nil

    location_restriction = if not is_nil(city), do: "rectangle:#{city.sw_lat},#{city.sw_lng}|#{city.ne_lat},#{city.ne_lng}", else: ""

    GoogleMapsHelper.fetch_autocomplete_place_details(
      search_text,
      iso_country_codes,
      lang_code,
      location_restriction,
      google_session_token
    )
  end

  def parse_polygon_searches(polygons) do
    Enum.map(polygons, fn polygon ->
      %{
        id: polygon.id,
        name: polygon.name,
        entity_type: "locality",
        entity_display_name: "Locality"
      }
    end)
  end

  def parse_building_searches(buildings) do
    Enum.map(buildings, fn building ->
      %{
        id: building.building_id,
        uuid: building.id,
        name: building.name,
        address: building.display_address,
        entity_type: "building",
        entity_display_name: "Building"
      }
    end)
  end

  def parse_google_autocomplete_searches(google_searches, list_of_polygon_names) do
    Enum.map(google_searches, fn google_search ->
      %{
        name: google_search.name,
        address: google_search.display_address,
        google_place_id: google_search.place_key,
        entity_type: "landmark",
        entity_display_name: "Landmark"
      }
    end)
    |> Enum.filter(fn x -> String.downcase(String.trim(x.name)) not in list_of_polygon_names end)
  end

  def get_polygon(name) do
    Polygon
    |> where([p], ilike(p.name, ^name) and p.is_active == true)
    |> Repo.one()
  end

  def fetch_from_uuid(nil), do: nil

  def fetch_from_uuid(uuid) do
    Polygon
    |> Repo.get_by(uuid: uuid, is_active: true)
  end

  def fetch_from_id(nil), do: nil

  def fetch_from_id(id) do
    Polygon
    |> Repo.get_by(id: id, is_active: true)
  end

  def all_polygons() do
    Polygon
    |> where([polygon], polygon.is_active == true)
    |> Repo.all()
  end

  def fetch_from_zone_id(zone_id) do
    zone = Repo.get(Zone, zone_id)

    if is_nil(zone) do
      {:error, :not_found}
    else
      polygons =
        Polygon
        |> where([polygon], polygon.zone_id == ^zone_id and polygon.is_active == true)
        |> Repo.all()

      {:ok, polygons}
    end
  end

  def fetch_from_city_id(city_id) do
    city = Repo.get(City, city_id)

    if is_nil(city) do
      {:error, :not_found}
    else
      polygons =
        Polygon
        |> where([polygon], polygon.city_id == ^city_id and polygon.is_active == true)
        |> Repo.all()

      {:ok, polygons}
    end
  end

  def add_zone_to_polygon_id(%{"zone_id" => zone_id, "polygon_id" => polygon_id}) do
    zone = Repo.get(Zone, zone_id)

    if is_nil(zone) do
      {:error, "Zone not found"}
    else
      polygon = Repo.get_by(Polygon, id: polygon_id, is_active: true)

      if is_nil(polygon) do
        {:error, "Polygon not found"}
      else
        polygon
        |> changeset(%{"zone_id" => zone_id})
        |> Repo.update!()

        {:ok, polygon}
      end
    end
  end
end
