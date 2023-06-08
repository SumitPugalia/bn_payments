defmodule BnApis.FeedTransactions.FeedTransactionLocality do
  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query

  alias BnApis.Repo
  alias BnApis.FeedTransactions.FeedTransactionLocality
  alias BnApis.Places.Polygon
  alias BnApis.Places.City

  @items_per_page 5

  schema "feed_transaction_localities" do
    field :feed_locality_id, :integer
    field :feed_locality_name, :string
    field :polygon_uuids, {:array, :string}
    field :city_id, :integer
    field :propstack_city_id, :integer

    timestamps()
  end

  @fields [
    :feed_locality_id,
    :feed_locality_name,
    :polygon_uuids,
    :city_id,
    :propstack_city_id
  ]
  @required_fields [:feed_locality_id, :feed_locality_name]

  @doc false
  def changeset(feed_transaction_locality, attrs \\ %{}) do
    feed_transaction_locality
    |> cast(attrs, @fields)
    |> validate_required(@required_fields)
    |> unique_constraint(:feed_locality_id)
  end

  def update(feed_transaction_locality, attrs) do
    feed_transaction_locality
    |> FeedTransactionLocality.changeset(attrs)
    |> Repo.update()
  end

  def all_localities() do
    FeedTransactionLocality
    |> order_by(asc: :feed_locality_name)
    |> Repo.all()
  end

  def fetch_by_feed_locality_id(feed_locality_id) do
    FeedTransactionLocality
    |> where(feed_locality_id: ^feed_locality_id)
    |> Repo.all()
    |> List.last()
  end

  def get_default_feed_locality(polygon_uuid) do
    FeedTransactionLocality
    |> where([l], ^polygon_uuid in l.polygon_uuids)
    |> limit(1)
    |> select([l], %{
      id: l.feed_locality_id,
      name: l.feed_locality_name,
      city_id: l.city_id
    })
    |> Repo.all()
    |> List.last()
  end

  def get_feed_locality_ids_by_city_id(city_id) do
    FeedTransactionLocality
    |> where([l], l.city_id == ^city_id)
    |> Repo.all()
    |> Enum.map(& &1.feed_locality_id)
  end

  def search_locality_query(search_text, city_id) do
    modified_search_text = "%" <> search_text <> "%"

    query =
      FeedTransactionLocality
      |> where([l], ilike(l.feed_locality_name, ^modified_search_text))

    query =
      if not is_nil(city_id) do
        query |> where([l], l.city_id == ^city_id)
      else
        query
      end

    query
    |> order_by([l], fragment("lower(?) <-> ?", l.feed_locality_name, ^search_text))
    |> limit(^@items_per_page)
    |> select([l], %{
      id: l.feed_locality_id,
      name: l.feed_locality_name,
      type: "locality"
    })
  end

  def get_details(feed_locality) do
    city =
      if not is_nil(feed_locality.city_id),
        do: City.get_city_data(Repo.get_by(City, id: feed_locality.city_id)),
        else: %{}

    polygon_uuids = feed_locality.polygon_uuids

    polygons =
      cond do
        not is_nil(polygon_uuids) ->
          Polygon
          |> where([p], p.uuid in ^polygon_uuids)
          |> select(
            [p],
            %{
              uuid: p.uuid,
              name: p.name
            }
          )
          |> Repo.all()

        true ->
          []
      end

    %{
      feed_locality_id: feed_locality.feed_locality_id,
      feed_locality_name: feed_locality.feed_locality_name,
      city: city,
      polygons: polygons,
      propstack_city_id: feed_locality.propstack_city_id
    }
  end
end
