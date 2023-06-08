defmodule BnApis.Buildings do
  @moduledoc """
  The Buildings context.
  """

  import Ecto.Query, warn: false
  alias BnApis.Repo

  alias BnApis.Buildings.{SourceType, Building}
  alias BnApis.Posts.MatchHelper
  alias BnApis.Posts.RentalPropertyPost
  alias BnApis.Posts.ResalePropertyPost
  alias BnApis.Buildings.BuildingEnums
  alias BnApis.Documents.Document
  alias BnApis.Buildings.PublicTransaction
  alias BnApis.Helpers.Utils
  alias BnApis.Posts.ConfigurationType

  @suggestions_limit 25
  @landmark_suggestions_limit 25
  @buildings_per_page 25

  def fetch_matching_buildings(post_type, filters, geom, city_id, building_type_ids) do
    exclude_building_ids = if not is_nil(filters["exclude_building_ids"]), do: filters["exclude_building_ids"], else: []

    if post_type == "rent" do
      filters
      |> BnApis.Posts.RentalMatch.filter_matching_buildings(city_id, building_type_ids, exclude_building_ids)
      |> Enum.uniq()
      |> Building.calculate_distance_and_sort(geom, true)
      |> Enum.slice(0, @suggestions_limit)
      |> handle_location()
    else
      filters
      |> BnApis.Posts.ResaleMatch.filter_matching_buildings(city_id, building_type_ids, exclude_building_ids)
      |> Enum.uniq()
      |> Building.calculate_distance_and_sort(geom, true)
      # |> edit_distance_addition_and_sort()
      |> Enum.slice(0, @suggestions_limit)
      |> handle_location()
    end
  end

  def edit_distance_addition_and_sort(results) do
    results
    |> Enum.map(
      &put_in(
        &1,
        [:edit_distance],
        MatchHelper.dotproduct(MatchHelper.resale_edit_distance_vector(&1), MatchHelper.resale_weight_vector())
      )
    )
    |> Enum.sort_by(& &1.edit_distance)
    |> Enum.uniq_by(& &1.id)
  end

  def get_search_suggestions(search_text, exclude_building_uuids, city_id, type_id) do
    Building.search_building_query(search_text, exclude_building_uuids, city_id, @buildings_per_page, type_id)
    |> Repo.all()
    |> Enum.map(&format_building/1)

    # |> sort_by_owner_posts_availability() removing this to check performance - this API is getting timeout too frequently
  end

  def get_admin_search_suggestions(search_text, exclude_building_uuids, city_id, polygon_id, type_id) do
    Building.admin_search_building_query(
      search_text,
      exclude_building_uuids,
      city_id,
      @buildings_per_page,
      polygon_id,
      type_id
    )
    |> Repo.all()
    |> Enum.map(&format_building/1)
  end

  def fetch_nearby_buildings(geom, city_id, type_id, exclude_building_ids) do
    city_id
    |> Building.city_buildings_query(geom, type_id, exclude_building_ids)
    |> Repo.all()
    # |> Building.calculate_distance_and_sort(geom)
    |> Enum.map(&format_building/1)
  end

  def limit_landmark_building_suggestions(results) do
    results
    |> Enum.slice(0, @landmark_suggestions_limit)
  end

  def get_similar_buildings(search_text, exclude_building_uuids, city_id, type_id) do
    Building.similar_building_query(search_text, exclude_building_uuids, city_id, @buildings_per_page, type_id)
    |> Repo.all()
    |> Enum.map(&format_building/1)

    # |> sort_by_owner_posts_availability()
  end

  def handle_location(buildings) do
    buildings
    |> Enum.map(fn building ->
      if building[:location] |> is_nil() do
        building |> put_in([:coordinates], [])
      else
        building |> put_in([:coordinates], (building[:location] |> Geo.JSON.encode!())["coordinates"])
      end
      |> Map.delete(:location)
    end)
  end

  def handle_location_for_buiding(building) do
    if building[:location] |> is_nil() do
      building |> put_in([:coordinates], [])
    else
      building |> put_in([:coordinates], (building[:location] |> Geo.JSON.encode!())["coordinates"])
    end
    |> Map.delete(:location)
  end

  def sort_by_owner_posts_availability(buildings) do
    building_uuids = buildings |> Enum.map(& &1[:id])

    rental_owner_post_building_uuids =
      RentalPropertyPost
      |> join(:inner, [r], b in Building, on: b.id == r.building_id)
      |> where([r, b], r.uploader_type == "owner" and b.uuid in ^building_uuids)
      |> distinct(true)
      |> select([r, b], b.uuid)
      |> Repo.all()

    resale_owner_post_building_uuids =
      ResalePropertyPost
      |> join(:inner, [r], b in Building, on: b.id == r.building_id)
      |> where([r, b], r.uploader_type == "owner" and b.uuid in ^building_uuids)
      |> distinct(true)
      |> select([r, b], b.uuid)
      |> Repo.all()

    owner_post_building_uuids = rental_owner_post_building_uuids ++ resale_owner_post_building_uuids

    buildings
    |> Enum.sort_by(fn building -> Enum.member?(owner_post_building_uuids, building[:id]) end, &>=/2)
  end

  def get_ids_from_uids(uids) do
    buildings =
      Building.get_ids_from_uids_query(uids)
      |> Repo.all()
      |> Enum.map(& &1.id)

    if buildings |> length == uids |> length do
      {:ok, buildings}
    else
      {:error, "Couldn't find building id!"}
    end
  end

  def get_building_data_from_ids(uuids, ids \\ []) do
    buildings = Building.get_building_polygon_data(uuids, ids)
    {:ok, buildings}
  end

  @doc """
  Returns the list of buildings_source_types.

  ## Examples

      iex> list_buildings_source_types()
      [%SourceType{}, ...]

  """
  def list_buildings_source_types do
    Repo.all(SourceType)
  end

  @doc """
  Gets a single source_type.

  Raises `Ecto.NoResultsError` if the Source type does not exist.

  ## Examples

      iex> get_source_type!(123)
      %SourceType{}

      iex> get_source_type!(456)
      ** (Ecto.NoResultsError)

  """
  def get_source_type!(id), do: Repo.get!(SourceType, id)

  @doc """
  Creates a source_type.

  ## Examples

      iex> create_source_type(%{field: value})
      {:ok, %SourceType{}}

      iex> create_source_type(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_source_type(attrs \\ %{}) do
    %SourceType{}
    |> SourceType.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a source_type.

  ## Examples

      iex> update_source_type(source_type, %{field: new_value})
      {:ok, %SourceType{}}

      iex> update_source_type(source_type, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_source_type(%SourceType{} = source_type, attrs) do
    source_type
    |> SourceType.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a SourceType.

  ## Examples

      iex> delete_source_type(source_type)
      {:ok, %SourceType{}}

      iex> delete_source_type(source_type)
      {:error, %Ecto.Changeset{}}

  """
  def delete_source_type(%SourceType{} = source_type) do
    Repo.delete(source_type)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking source_type changes.

  ## Examples

      iex> change_source_type(source_type)
      %Ecto.Changeset{source: %SourceType{}}

  """
  def change_source_type(%SourceType{} = source_type) do
    SourceType.changeset(source_type, %{})
  end

  alias BnApis.Buildings.Building

  @doc """
  Returns the list of buildings.

  ## Examples

      iex> list_buildings()
      [%Building{}, ...]

  """
  def list_buildings do
    Repo.all(Building)
  end

  defp get_polygon_info(nil), do: %{}

  defp get_polygon_info(polygon) do
    %{
      id: polygon.id,
      uuid: polygon.uuid,
      name: polygon.name,
      city_id: polygon.city_id
    }
  end

  def get_building_info(building) do
    building = building |> Repo.preload([:polygon])
    polygon_info = get_polygon_info(building.polygon)

    %{
      id: building.uuid,
      building_id: building.id,
      name: building.name,
      display_address: building.display_address,
      location: building.location,
      structure: building.structure,
      car_parking_ratio: building.car_parking_ratio,
      total_development_size: building.total_development_size,
      type_id: BuildingEnums.get_building_type_id(building.type),
      grade_id: BuildingEnums.get_building_grade_id(building.grade),
      polygon: polygon_info
    }
    |> fetch_and_append_building_images()
  end

  def admin_list_buildings(params) do
    {query, content_query, page_no, size} = Building.admin_filter_query(params)

    buildings =
      content_query
      |> order_by([b, p], desc: b.inserted_at)
      |> Building.fetch_building_info()
      |> Repo.all()
      |> Enum.map(&format_building(&1, true))

    total_count = query |> distinct(:id) |> Repo.aggregate(:count, :id)
    next_page_exists = page_no < Float.ceil(total_count / size)

    response = %{
      "buildings" => buildings,
      "has_more" => next_page_exists,
      "total_count" => total_count,
      "next_page_query_params" => "p=#{page_no + 1}"
    }

    {:ok, response}
  end

  @doc """
  Gets a single building.

  Raises `Ecto.NoResultsError` if the Building does not exist.

  ## Examples

      iex> get_building!(123)
      %Building{}

      iex> get_building!(456)
      ** (Ecto.NoResultsError)

  """
  def get_building!(id), do: Repo.get!(Building, id)

  def get_building_by_uuid(uuid) do
    case Repo.get_by(Building, uuid: uuid) do
      nil -> nil
      building -> get_building_info(building)
    end
  end

  @doc """
  Creates a building.

  ## Examples

      iex> create_building(%{field: value})
      {:ok, %Building{}}

      iex> create_building(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_building(attrs \\ %{}) do
    %Building{}
    |> Building.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a building.

  ## Examples

      iex> update_building(building, %{field: new_value})
      {:ok, %Building{}}

      iex> update_building(building, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_building(%Building{} = building, attrs) do
    case Building.update_building(building, attrs) do
      {:ok, building} -> {:ok, get_building_info(building)}
      {:error, changeset} -> {:error, changeset}
    end
  end

  @doc """
  Deletes a Building.

  ## Examples

      iex> delete_building(building)
      {:ok, %Building{}}

      iex> delete_building(building)
      {:error, %Ecto.Changeset{}}

  """
  def delete_building(%Building{} = building) do
    Repo.delete(building)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking building changes.

  ## Examples

      iex> change_building(building)
      %Ecto.Changeset{source: %Building{}}

  """
  def change_building(%Building{} = building) do
    Building.changeset(building, %{})
  end

  def meta_data() do
    meta_data = BuildingEnums.get_all_enums()
    {:ok, meta_data}
  end

  def format_building(building, attach_images \\ false) do
    building =
      building
      |> handle_commercial_building_attrs()
      |> handle_location_for_buiding()

    if(attach_images == true) do
      building |> fetch_and_append_building_images()
    else
      building
    end
  end

  def handle_commercial_building_attrs(building) do
    building
    |> put_in([:grade_id], BuildingEnums.get_building_grade_id(building[:grade]))
    |> put_in([:type_id], BuildingEnums.get_building_type_id(building[:type]))
    |> Map.delete(:grade)
    |> Map.delete(:type)
  end

  def fetch_and_append_building_images(building) do
    {docs, _number_of_documents} = Document.get_document(building.building_id, Building.get_entity_type(), true)
    building |> put_in([:documents], docs)
  end

  def upload_document(params, user_id) do
    documents = params["documents"]

    if is_list(documents) and length(documents) > 0 do
      case Repo.get(Building, params["building_id"]) do
        nil ->
          {:error, %{message: "invalid building id"}}

        _building ->
          Document.upload_document(documents, user_id, Building.get_entity_type(), "employee")
          {uploaded_docs, _number_of_documents} = Document.get_document(params["building_id"], Building.get_entity_type(), true)
          {:ok, %{message: "images uploaded succesfully", uploaded_docs: uploaded_docs, status: true}}
      end
    else
      {:ok, %{message: "No images to be uploaded"}}
    end
  end

  def remove_document(params) do
    entity_id = Utils.parse_to_integer(params["entity_id"])
    doc_id = Utils.parse_to_integer(params["doc_id"])
    Document.remove_document(doc_id, entity_id, Building.get_entity_type())
  end

  def save_building_txn(building_id, filepath_to_save) do
    File.stream!(filepath_to_save)
    |> CSV.decode(strip_fields: true, headers: true)
    |> Enum.to_list()
    |> Enum.map(&create_building_transaction_params(building_id, &1))
    |> Enum.reject(&is_nil/1)
    |> (&Repo.insert_all(PublicTransaction, &1, on_conflict: :nothing)).()

    :ok
  end

  def fetch_building_transactions(building_id) do
    PublicTransaction
    |> where([p], p.building_id == ^building_id)
    |> order_by([p], desc: p.transaction_date)
    |> Repo.all()
  end

  def create_building_transaction_params(building_id, {:ok, data}) do
    configuration_type_id =
      case data["configuration_type"] |> ConfigurationType.get_by_name() do
        nil -> raise "invalid configuration_type for #{data["wing"]} #{data["unit_number"]} for #{data["configuration_type"]}"
        %{id: configuration_type_id} -> configuration_type_id
      end

    ## 2019-07-03
    transaction_data =
      (data["transaction_date"] <> " 00:00:00")
      |> NaiveDateTime.from_iso8601()
      |> case do
        {:ok, dt} -> dt
        {:error, _} -> raise "invalid transaction_data for #{data["wing"]} #{data["unit_number"]} for #{data["transaction_date"]}"
      end

    price =
      data["price"]
      |> Utils.parse_to_integer()
      |> case do
        nil -> raise "invalid price for #{data["wing"]} #{data["unit_number"]} for #{data["price"]}"
        price -> price
      end

    area =
      data["area"]
      |> Utils.parse_to_integer()
      |> case do
        nil -> raise "invalid area for #{data["wing"]} #{data["unit_number"]} for #{data["area"]}"
        area -> area
      end

    %{
      wing: data["wing"],
      area: area,
      price: price,
      unit_number: data["unit_number"],
      transaction_type: data["transaction_type"] |> String.to_atom(),
      transaction_date: transaction_data,
      building_id: building_id,
      configuration_type_id: configuration_type_id,
      inserted_at: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second),
      updated_at: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)
    }
  end
end
