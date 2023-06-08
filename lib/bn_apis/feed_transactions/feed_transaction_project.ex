defmodule BnApis.FeedTransactions.FeedTransactionProject do
  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query

  alias BnApis.FeedTransactions.FeedTransactionProject
  alias BnApis.FeedTransactions.FeedTransactionLocality

  @items_per_page 5

  schema "feed_transaction_projects" do
    field(:feed_project_id, :integer)
    field(:feed_project_name, :string)
    field(:feed_locality_id, :integer)
    field(:feed_locality_name, :string)
    field(:full_name, :string)

    timestamps()
  end

  @fields [
    :feed_project_id,
    :feed_project_name,
    :feed_locality_id,
    :feed_locality_name,
    :full_name
  ]
  @required_fields [:feed_project_id, :feed_project_name, :feed_locality_id, :feed_locality_name, :full_name]

  @doc false
  def changeset(feed_transaction_project, attrs \\ %{}) do
    feed_transaction_project
    |> cast(attrs, @fields)
    |> validate_required(@required_fields)
    |> unique_constraint(:feed_project_id)
  end

  def search_project_query(search_text, city_id) do
    modified_search_text = "%" <> search_text <> "%"

    query =
      FeedTransactionProject
      |> where([l], ilike(l.feed_project_name, ^modified_search_text))

    query =
      if not is_nil(city_id) do
        locality_ids = FeedTransactionLocality.get_feed_locality_ids_by_city_id(city_id)

        if length(locality_ids) > 0 do
          query |> where([t], t.feed_locality_id in ^locality_ids)
        else
          query
        end
      else
        query
      end

    query
    |> order_by([l], fragment("lower(?) <-> ?", l.feed_project_name, ^search_text))
    |> limit(^@items_per_page)
    |> select([l], %{
      id: l.feed_project_id,
      name: l.full_name,
      type: "project"
    })
  end
end
