defmodule BnApis.FeedTransactions.FeedTransaction do
  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query

  @per_page 10

  alias BnApis.Helpers.Time
  alias BnApis.FeedTransactions.FeedTransaction
  alias BnApis.FeedTransactions.FeedTransactionLocality

  # locality_id relationship internally
  # project_id relationship internally

  # field :transaction_type, Ecto.Enum, values: [:sale, :rent, :mortgage]
  # Note: Ecto.Enum is supported only after 3.5
  schema "feed_transactions" do
    field :comps_id, :integer
    field :transaction_type, :string
    field :feed_locality_id, :integer
    field :feed_locality_name, :string
    field :feed_project_id, :integer
    field :feed_project_name, :string
    field :consideration, :float
    field :converted_area, :float
    field :floor, :string
    field :registration_date, :naive_datetime
    field :rent_duration, :string
    field :area_type, :string
    field :tower, :string
    field :wing, :string
    field :propstack_city_id, :integer
    field :original_data, :map

    timestamps()
  end

  @fields [
    :area_type,
    :transaction_type,
    :comps_id,
    :feed_locality_id,
    :feed_locality_name,
    :feed_project_id,
    :feed_project_name,
    :consideration,
    :converted_area,
    :floor,
    :registration_date,
    :rent_duration,
    :tower,
    :wing,
    :propstack_city_id,
    :original_data
  ]
  @required_fields [:comps_id, :feed_locality_id, :feed_project_id]

  @doc false
  def changeset(feed_transaction, attrs \\ %{}) do
    feed_transaction
    |> cast(attrs, @fields)
    |> validate_required(@required_fields)
    |> unique_constraint(:comps_id)
  end

  def filter_query(params) do
    page =
      case not is_nil(params["page"]) and Integer.parse(params["page"]) do
        {val, _} -> val
        _ -> 1
      end

    size =
      case not is_nil(params["size"]) and Integer.parse(params["size"]) do
        {val, _} -> val
        _ -> @per_page
      end

    query =
      FeedTransaction
      |> where([t], t.consideration > 0.0 and not is_nil(t.consideration))
      |> where([t], t.converted_area > 0.0 and not is_nil(t.converted_area))

    # |> where([t], t.registration_date > 0.0 and not is_nil(t.converted_area))
    # registration_date >= 01-04-2017

    query =
      if is_nil(params["locality_id"]) and is_nil(params["project_id"]) and not is_nil(params["city_id"]) do
        locality_ids = FeedTransactionLocality.get_feed_locality_ids_by_city_id(params["city_id"])

        if length(locality_ids) > 0 do
          query |> where([t], t.feed_locality_id in ^locality_ids)
        else
          query
        end
      else
        query
      end

    query =
      if not is_nil(params["transaction_type"]),
        do: query |> where([t], t.transaction_type == ^params["transaction_type"]),
        else: query

    query =
      if not is_nil(params["locality_id"]),
        do: query |> where([t], t.feed_locality_id == ^params["locality_id"]),
        else: query

    query =
      if not is_nil(params["project_id"]),
        do: query |> where([t], t.feed_project_id == ^params["project_id"]),
        else: query

    query =
      if not is_nil(params["min_price"]) and not is_nil(params["max_price"]),
        do: query |> where([t], t.consideration >= ^params["min_price"] and t.consideration <= ^params["max_price"]),
        else: query

    query =
      if not is_nil(params["min_area"]) and not is_nil(params["max_area"]),
        do: query |> where([t], t.converted_area >= ^params["min_area"] and t.converted_area <= ^params["max_area"]),
        else: query

    query =
      if not is_nil(params["min_registration_date"]) and not is_nil(params["max_registration_date"]) do
        min_registration_date = params["min_registration_date"] |> Time.epoch_to_naive()
        max_registration_date = params["max_registration_date"] |> Time.epoch_to_naive()

        query
        |> where([t], t.registration_date >= ^min_registration_date and t.registration_date <= ^max_registration_date)
      else
        query
      end

    content_query =
      query
      |> order_by([t], desc: t.registration_date)
      |> limit(^size)
      |> offset(^((page - 1) * size))

    {query, content_query, page, size}
  end
end
