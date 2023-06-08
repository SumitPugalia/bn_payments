defmodule BnApis.Transactions.Building do
  use Ecto.Schema
  import Ecto.Changeset
  alias BnApis.Transactions.Building
  import Ecto.Query
  alias BnApis.Repo
  alias BnApis.Places.Locality

  @buildings_per_page 10

  schema "transactions_buildings" do
    field :address, :string
    field :name, :string
    field :locality, :string
    field :place_id, :string
    field :plus_code, :string
    field :location, Geo.PostGIS.Geometry
    field :delete, :boolean, default: false

    field :locality_id, :id

    timestamps()
  end

  @doc false
  def changeset(building, attrs) do
    building
    |> cast(attrs, [:name, :address, :plus_code, :place_id, :location, :locality, :delete, :locality_id])
    |> validate_required([:name, :place_id, :location])
  end

  def changeset(attrs) do
    %__MODULE__{}
    |> changeset(attrs)
  end

  def locality_id_changeset(building, locality_id) do
    building
    |> change(locality_id: locality_id)
  end

  def mark_buildings_as_deleted(building_ids) do
    Building
    |> where([b], b.id in ^building_ids)
    |> Ecto.Query.update(set: [delete: true])
    |> Repo.update_all([])
  end

  def fetch_building_by_place_id(place_id) do
    Building
    |> where([b], b.place_id == ^place_id and is_nil(b.locality))
    |> Repo.all()
    |> List.first()
  end

  def fetch_building_by_place_id(place_id, name) do
    Building
    |> where([b], b.place_id == ^place_id and b.name == ^name and not is_nil(b.locality))
    |> Repo.all()
    |> List.first()
  end

  def create_building(params) do
    Building.changeset(params) |> Repo.insert()
  end

  def get_or_create_building(params) do
    building = fetch_building_by_place_id(params["place_id"])

    case building do
      nil ->
        Building.changeset(params) |> Repo.insert()

      _ ->
        {:ok, building}
    end
  end

  def get_or_create_locality_building(params) do
    building = fetch_building_by_place_id(params["place_id"], params["name"])

    case building do
      nil ->
        Building.changeset(params) |> Repo.insert()

      _ ->
        {:ok, building}
    end
  end

  def search_building_query(search_text, locality_uuid) do
    modified_search_text = "%" <> search_text <> "%"

    Building
    |> join(:inner, [b], l in Locality, on: b.locality_id == l.id)
    |> where(
      [b, l],
      l.uuid == ^locality_uuid and b.delete == false
    )
    |> where([b], ilike(b.name, ^modified_search_text))
    |> order_by([b], asc: fragment("lower(?) <-> ?", b.name, ^search_text), asc: b.locality)
    |> select(
      [b],
      %{
        id: b.id,
        name: b.name,
        address: b.address,
        locality: b.locality,
        place_id: b.place_id
      }
    )
    |> limit(@buildings_per_page)
  end

  def search_building_query(search_text) do
    modified_search_text = "%" <> search_text <> "%"

    Building
    |> where(delete: false)
    |> where([b], ilike(b.name, ^modified_search_text))
    |> order_by([b], asc: fragment("lower(?) <-> ?", b.name, ^search_text), asc: b.locality)
    |> select(
      [b],
      %{
        id: b.id,
        name: b.name,
        address: b.address,
        locality: b.locality,
        place_id: b.place_id
      }
    )
    |> limit(@buildings_per_page)
  end

  def search_db_buildings_query(search_text) do
    Building
    |> where(delete: false)
    |> where([b], fragment("similarity(concat(?,' ',?,' ',?), ?) > 0.1", b.name, b.address, b.locality, ^search_text))
    |> order_by([b],
      asc: fragment("concat(?,' ',?,' ',?) <-> ?", b.name, b.address, b.locality, ^search_text),
      asc: b.locality
    )
    |> select(
      [b],
      %{
        id: b.id,
        name: b.name,
        address: b.address,
        locality: b.locality,
        place_id: b.place_id
      }
    )
    |> limit(@buildings_per_page)
  end

  alias BnApis.Accounts.EmployeeCredential
  alias BnApis.Transactions.{Transaction, TransactionData}

  @doc """
    Sends user_detail aswell for monitoring/informing
  """
  def search_using_trgm_building_query(search_text) do
    query =
      Building
      |> join(:inner, [b], t in Transaction, on: t.transaction_building_id == b.id)
      |> join(:inner, [b, t], td in TransactionData, on: td.id == t.transaction_data_id)
      |> join(:inner, [b, t, td], c in EmployeeCredential, on: c.id == td.assignee_id)
      |> where([b, t, td, c], b.delete == false)
      |> where([b], fragment("similarity(?, ?) > 0.5", b.name, ^search_text))
      |> order_by([b], asc: b.locality, asc: b.address, asc: fragment("? <-> ?", b.name, ^search_text))
      |> select(
        [b, t, td, c],
        %{
          id: b.id,
          name: b.name,
          address: b.address,
          locality: b.locality,
          place_id: b.place_id,
          user_detail: fragment("concat(?,', ',?)", c.name, c.phone_number),
          rn: fragment("ROW_NUMBER() OVER (PARTITION BY ? ORDER BY ? asc)", b.id, t.inserted_at)
        }
      )

    query
    |> subquery()
    |> where([e], e.rn == 1)
  end

  def get_building_info(building_id) do
    Building
    |> where(id: ^building_id)
    |> select([b], %{
      id: b.id,
      name: b.name,
      address: b.address,
      locality: b.locality,
      place_id: b.place_id
    })
    |> Repo.one()
  end

  def get_building_name(building_id) do
    Building
    |> where(id: ^building_id)
    |> select([b], b.name)
    |> Repo.one()
  end
end
