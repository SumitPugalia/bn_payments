defmodule BnApis.Transactions.Transaction do
  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query

  alias BnApis.Transactions.{Transaction, TransactionData, TransactionVersion, Building, Status}
  alias BnApis.Places.Locality
  alias BnApis.Repo

  @per_page 10

  schema "transactions" do
    field :flat_no, :string
    field :floor_no, :integer
    field :area, :decimal
    field :price, :integer
    field :rent, :integer
    # in months
    field :tenure_for_rent, :integer
    # "rent/resale"
    field :transaction_type, :string
    field :registration_date, :naive_datetime
    field :correct, :boolean
    field :wrong_reason, :string

    belongs_to :transaction_data, TransactionData
    belongs_to :transaction_building, Building

    has_many :transactions_verions, TransactionVersion

    timestamps()
  end

  @required [:flat_no, :floor_no, :area, :transaction_type, :transaction_data_id]
  @fields @required ++ [:price, :rent, :tenure_for_rent, :transaction_building_id, :registration_date]

  @doc false
  def changeset(transaction, attrs) do
    transaction
    |> cast(attrs, @fields)
    |> validate_required(@required)
    |> unique_constraint(:transaction_data_id, message: "Transaction Data Already cleaned!!")
  end

  def changeset(attrs) do
    %__MODULE__{}
    |> changeset(attrs)
  end

  def mark_correct_changeset(transaction_id) do
    transaction = Repo.get!(Transaction, transaction_id)
    transaction |> change(correct: true)
  end

  def mark_wrong_changeset(transaction_id, wrong_reason) do
    transaction = Repo.get!(Transaction, transaction_id)
    transaction |> change(correct: false) |> change(wrong_reason: wrong_reason)
  end

  def fetch_random_transaction_query(employee_id) do
    Transaction
    |> join(:inner, [t], td in TransactionData, on: t.transaction_data_id == td.id)
    |> where([t, td], td.assignee_id == ^employee_id and is_nil(t.correct))
    |> order_by(fragment("RANDOM()"))
    |> preload([:transactions_verions, :transaction_data, :transaction_building])
    |> limit(1)
    |> Repo.one()
    |> handle_invalid_area()
    |> merge_with_versions()
  end

  def merge_with_versions(transaction) when is_nil(transaction), do: nil

  def merge_with_versions(transaction) do
    versions = transaction.transactions_verions
    transaction = transaction |> Map.delete(:transactions_verions)

    versions
    |> Enum.reduce(transaction, fn version, _acc ->
      version = version |> remove_nil() |> Map.delete(:id)
      transaction |> Map.merge(version)
    end)
  end

  def handle_invalid_area(transaction) do
    area = (transaction.area && transaction.area |> Decimal.to_float() |> round()) || 0
    area = if area <= 0 or area == 1, do: Decimal.new(0), else: transaction.area
    transaction |> Map.merge(%{area: area})
  end

  def remove_nil(map) do
    map |> Map.from_struct() |> Enum.filter(fn {_, v} -> not is_nil(v) end) |> Enum.into(%{})
  end

  @global_min_area 10
  @global_max_area 10000
  @global_min_rent 100
  @global_min_price 1000

  def search_base_query(locality_uuid, type, page) do
    processed_id = Status.processed().id

    Transaction
    |> join(:inner, [t], b in Building, on: t.transaction_building_id == b.id)
    |> join(:inner, [t, b], l in Locality, on: b.locality_id == l.id)
    |> join(:left, [t, b, l], td in TransactionData, on: t.transaction_data_id == td.id)
    |> where(
      [t, b, l],
      l.uuid == ^locality_uuid and b.delete == false
    )
    |> where(
      [t, b, l, td],
      # and t.correct == true
      td.status_id == ^processed_id and
        t.transaction_type == ^type
    )
    |> where(
      [t, b],
      t.area > ^@global_min_area and
        t.area < ^@global_max_area and
        (is_nil(t.price) or t.price > ^@global_min_price) and
        (is_nil(t.rent) or t.rent > ^@global_min_rent) and
        not is_nil(t.registration_date)
    )

    # base filters for now
    |> order_by([t, b, l, td], desc: t.registration_date)
    |> preload([:transactions_verions, :transaction_data, :transaction_building])
    |> distinct(true)
    |> limit(^@per_page)
    |> offset(^((page - 1) * @per_page))
  end

  def search_transactions_query(
        params = %{
          "locality_uuid" => locality_uuid,
          "page" => page,
          "type" => type
        }
      ) do
    query = search_base_query(locality_uuid, type, page)

    query =
      if not is_nil(params["building_id"]),
        do: query |> where([t, b, l, td], b.id == ^params["building_id"]),
        else: query

    query = if not is_nil(params["min_area"]), do: query |> where([t], t.area >= ^params["min_area"]), else: query
    query = if not is_nil(params["max_area"]), do: query |> where([t], t.area <= ^params["max_area"]), else: query
    query = if not is_nil(params["min_price"]), do: query |> where([t], t.price >= ^params["min_price"]), else: query
    query = if not is_nil(params["max_price"]), do: query |> where([t], t.price <= ^params["max_price"]), else: query
    query = if not is_nil(params["min_rent"]), do: query |> where([t], t.rent >= ^params["min_rent"]), else: query
    query = if not is_nil(params["max_rent"]), do: query |> where([t], t.rent <= ^params["max_rent"]), else: query

    query
    |> Repo.all()
    |> Enum.map(fn transaction ->
      transaction
      |> handle_invalid_area()
      |> merge_with_versions()
    end)
  end

  def get_ranges_for_transactions(locality_id) do
    Transaction
    |> join(:inner, [t], b in Building, on: t.transaction_building_id == b.id)
    |> where([t, b], b.locality_id == ^locality_id)
    |> distinct(true)
    |> where(
      [t, b],
      t.area > ^@global_min_area and
        t.area < ^@global_max_area and
        (is_nil(t.price) or t.price > ^@global_min_price) and
        (is_nil(t.rent) or t.rent > ^@global_min_rent)
    )

    # base filters for now
    |> select([t, b], %{
      count: count(t.id),
      min_price: min(t.price),
      max_price: max(t.price),
      min_rent: min(t.rent),
      max_rent: max(t.rent),
      min_area: min(t.area),
      max_area: max(t.area)
    })
    |> Repo.all()
    |> List.first()
    |> fix_area_filter()
  end

  def fix_area_filter(filters) do
    min_area = (filters.min_area && filters.min_area |> Decimal.to_float() |> round()) || 0
    min_area = if min_area <= 0 or min_area == 1, do: Decimal.new(0), else: filters.min_area

    max_area = (filters.max_area && filters.max_area |> Decimal.to_float() |> round()) || 0
    max_area = if max_area <= 0 or max_area == 1, do: Decimal.new(0), else: filters.max_area

    filters |> Map.merge(%{min_area: min_area, max_area: max_area})
  end
end
