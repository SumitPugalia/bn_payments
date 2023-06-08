defmodule BnApis.Orders.MatchPlusPackage do
  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query, warn: false
  alias BnApis.Repo

  alias BnApis.Memberships.Membership
  alias BnApis.Orders.MatchPlusPackage
  alias BnApis.Orders.Order
  alias BnApis.Helpers.Time
  alias BnApis.Places.City

  @active_status_id 1
  @inactive_status_id 2

  @days_in_month 30

  @derive {Jason.Encoder,
           only: [
             :uuid,
             :status_id,
             :original_amount_in_rupees,
             :amount_in_rupees,
             :validity_in_days,
             :offer_title,
             :offer_text,
             :is_default,
             :autopay,
             :rules,
             :payment_gateway,
             :payment_prefs,
             :city_id
           ]}
  schema "match_plus_packages" do
    field :uuid, Ecto.UUID, read_after_writes: true
    field :status_id, :integer
    field :original_amount_in_rupees, :integer
    field :amount_in_rupees, :integer
    field :validity_in_days, :integer
    field :offer_title, :string
    field :offer_text, :string
    field :is_default, :boolean, default: false
    field :autopay, :boolean, default: false
    field :rules, :map
    field :payment_gateway, Ecto.Enum, values: [:paytm, :razorpay, :billdesk], default: :razorpay
    field :payment_prefs, {:array, :string}, default: []
    field :package_type, Ecto.Enum, values: [:owners, :commercial], default: :owners
    belongs_to(:city, City)

    has_many(:orders, Order, foreign_key: :match_plus_package_id)
    has_many(:memberships, Membership, foreign_key: :match_plus_package_id)

    timestamps()
  end

  @required [:original_amount_in_rupees, :amount_in_rupees, :validity_in_days, :status_id, :is_default, :package_type]
  @optional [:offer_title, :offer_text, :autopay, :city_id, :rules]

  @special_offers_for_paytm_broker_ids [
    5061,
    13844,
    94377,
    47206,
    80742,
    2057,
    19832,
    8823,
    94932,
    87080,
    92076,
    93461,
    816,
    3736,
    95454,
    86678,
    76773,
    4969,
    2324,
    43193,
    6663,
    53560,
    95554,
    77566,
    28976,
    9551,
    3571,
    20761,
    5175,
    45801,
    2480,
    667,
    48959,
    78580,
    5626,
    3287,
    97344,
    78019,
    4408,
    35065,
    98191,
    53478,
    46617,
    45800,
    98299,
    48468,
    98701,
    750,
    97281,
    86265,
    44629,
    76103,
    49244,
    76227,
    76986,
    79059,
    99430,
    102,
    97770,
    100_462,
    43227,
    78227,
    13779,
    46093,
    11993,
    84925,
    97747
  ]

  @doc false
  def changeset(match_plus_package, attrs) do
    match_plus_package
    |> cast(attrs, @required ++ @optional)
    |> validate_required(@required)
    |> unique_constraint(:amount_in_rupees,
      name: :mp_packages_amount_city_unique_constraint_on_status_id_active,
      message: "An active match plus packages with same amount(in Rs) already exists for the same city."
    )
    |> unique_constraint(:is_default,
      name: :mp_packages_unique_index_on_active_default_pkg_for_city,
      message: "An active default match plus package already exists for the city."
    )
  end

  def days_in_month() do
    @days_in_month
  end

  def active_status_id() do
    @active_status_id
  end

  def inactive_status_id() do
    @inactive_status_id
  end

  def fetch_from_uuid(uuid) do
    MatchPlusPackage |> Repo.get_by(uuid: uuid)
  end

  def fetch_active_package_from_uuid(uuid) do
    MatchPlusPackage |> Repo.get_by(uuid: uuid, status_id: @active_status_id)
  end

  def fetch_active_autopay_package_from_uuid_and_city(uuid, city_id) do
    MatchPlusPackage |> Repo.get_by(uuid: uuid, autopay: true, city_id: city_id, status_id: @active_status_id)
  end

  def create(
        params = %{
          "original_amount_in_rupees" => original_amount_in_rupees,
          "amount_in_rupees" => amount_in_rupees,
          "validity_in_days" => validity_in_days,
          "is_default" => is_default
        }
      ) do
    offer_title = Map.get(params, "offer_title") |> parse_string()
    offer_text = Map.get(params, "offer_text") |> parse_string()
    city_id = Map.get(params, "city_id")
    autopay = Map.get(params, "autopay")

    %MatchPlusPackage{}
    |> changeset(%{
      status_id: @active_status_id,
      original_amount_in_rupees: original_amount_in_rupees,
      amount_in_rupees: amount_in_rupees,
      validity_in_days: validity_in_days,
      offer_title: offer_title,
      offer_text: offer_text,
      is_default: is_default,
      city_id: city_id,
      autopay: autopay
    })
    |> Repo.insert()
    |> case do
      {:ok, match_plus_package} ->
        {:ok, create_match_plus_package_map(match_plus_package)}

      {:error, error} ->
        {:error, error}
    end
  end

  def create(_params), do: {:error, "Invalid params."}

  def get_default_autopay_amount_by_city(city_id) do
    autopay_package =
      MatchPlusPackage
      |> where([p], p.autopay == true)
      |> where([p], p.city_id == ^city_id)
      |> where([p], p.status_id == ^@active_status_id)
      |> order_by([p], asc: p.amount_in_rupees)
      |> Repo.one()

    if not is_nil(autopay_package) do
      autopay_package.amount_in_rupees
    else
      Membership.amount()
    end
  end

  def get_data(user) do
    if is_nil(user[:operating_city]) do
      []
    else
      MatchPlusPackage
      |> where([p], p.status_id == ^@active_status_id)
      |> where([p], p.city_id == ^user[:operating_city])
      |> order_by(asc: :validity_in_days)
      |> Repo.all()
      |> filter_by_rules(user[:broker_id], user[:operating_city])
      |> Enum.map(fn package -> get_match_plus_package_data(package) end)
    end
  end

  def get_match_plus_package_data(nil) do
    %{}
  end

  def get_match_plus_package_data(package) do
    validity_in_days = package.validity_in_days

    offer_days =
      cond do
        package.offer_title == "Extra 30 days" -> 30
        package.offer_title == "Extra 45 days" -> 45
        package.offer_title == "Extra 60 days" -> 60
        true -> 0
      end

    number_of_months = floor((validity_in_days - offer_days) / @days_in_month)
    price_per_month = floor(package.amount_in_rupees / number_of_months)

    %{
      id: package.id,
      active: package.status_id == @active_status_id,
      uuid: package.uuid,
      original_price: package.original_amount_in_rupees,
      price: package.amount_in_rupees,
      validity_in_days: validity_in_days,
      number_of_months: number_of_months,
      price_per_month: price_per_month,
      offer_applied: package.original_amount_in_rupees != package.amount_in_rupees,
      offer_title: package.offer_title,
      offer_text: package.offer_text,
      default_selection: package.is_default,
      autopay: package.autopay,
      city_id: package.city_id,
      payment_gateway: package.payment_gateway,
      package_type: package.package_type
    }
  end

  def fetch_active_package_for_city_with_amount(broker, amount) do
    broker_id = broker.id
    city_id = broker.operating_city

    MatchPlusPackage
    |> where([p], p.amount_in_rupees == ^amount)
    |> where([p], p.status_id == ^@active_status_id)
    |> where([p], p.city_id == ^city_id)
    |> Repo.all()
    |> filter_by_rules(broker_id, city_id)
    |> Enum.at(0)

    # MatchPlusPackage |> Repo.get_by(amount_in_rupees: amount, status_id: @active_status_id, city_id: city_id)
  end

  def all_match_plus_data(params) do
    page_no = Map.get(params, "p", "1") |> String.to_integer()
    limit = Map.get(params, "limit", "30") |> String.to_integer()

    get_paginated_results(page_no, limit)
  end

  def fetch_match_plus_data_by_uuid(uuid) do
    uuid
    |> fetch_match_plus_data_from_repo()
    |> create_match_plus_package_map()
  end

  def update_match_plus_record(
        params = %{
          "uuid" => uuid,
          "original_amount_in_rupees" => original_amount_in_rupees,
          "amount_in_rupees" => amount_in_rupees,
          "validity_in_days" => validity_in_days,
          "status_id" => status_id,
          "is_default" => is_default
        }
      ) do
    offer_title = Map.get(params, "offer_title") |> parse_string()
    offer_text = Map.get(params, "offer_text") |> parse_string()
    city_id = Map.get(params, "city_id")
    autopay = Map.get(params, "autopay")

    match_plus_record = fetch_match_plus_data_from_repo(uuid)

    if is_nil(match_plus_record) do
      {:error, "Match Plus Package not found"}
    else
      match_plus_record
      |> changeset(%{
        "original_amount_in_rupees" => original_amount_in_rupees,
        "amount_in_rupees" => amount_in_rupees,
        "validity_in_days" => validity_in_days,
        "status_id" => status_id,
        "offer_title" => offer_title,
        "offer_text" => offer_text,
        "is_default" => is_default,
        "city_id" => city_id,
        "autopay" => autopay
      })
      |> Repo.update()
    end
  end

  def update_match_plus_record(_params), do: {:error, "Invalid params."}

  ## Private API's

  defp parse_string(nil), do: ""
  defp parse_string(string), do: String.trim(string)

  defp fetch_match_plus_data_from_repo(uuid), do: MatchPlusPackage |> Repo.get_by(uuid: uuid)

  defp get_paginated_results(page_no, limit) do
    offset = (page_no - 1) * limit

    match_plus_packages =
      MatchPlusPackage
      |> order_by(asc: :validity_in_days)
      |> limit(^limit)
      |> offset(^offset)
      |> Repo.all()

    match_plus_packages_map =
      match_plus_packages
      |> Enum.map(fn match_plus_package ->
        create_match_plus_package_map(match_plus_package)
      end)

    %{
      "match_plus_packages" => match_plus_packages_map,
      "next_page_exists" => Enum.count(match_plus_packages) >= limit,
      "next_page_query_params" => "p=#{page_no + 1}"
    }
  end

  defp create_match_plus_package_map(nil), do: nil

  defp create_match_plus_package_map(match_plus_package) do
    %{
      "id" => match_plus_package.id,
      "uuid" => match_plus_package.uuid,
      "status_id" => match_plus_package.status_id,
      "original_amount_in_rupees" => match_plus_package.original_amount_in_rupees,
      "amount_in_rupees" => match_plus_package.amount_in_rupees,
      "validity_in_days" => match_plus_package.validity_in_days,
      "offer_title" => match_plus_package.offer_title,
      "offer_text" => match_plus_package.offer_text,
      "is_default" => match_plus_package.is_default,
      "autopay" => match_plus_package.autopay,
      "city_id" => match_plus_package.city_id,
      "payment_gateway" => match_plus_package.payment_gateway
    }
  end

  defp filter_by_rules(packages, broker_id, city_id) do
    generic_packages = packages |> Enum.filter(fn package -> is_nil(package.rules) end)
    latest_paid_order = Order.get_latest_paid_order_of_a_broker(broker_id)
    latest_cancelled_membership = Membership.latest_membership_by_broker_by_status(broker_id, Membership.reject_status())

    subscription_expired_in_days_ago =
      cond do
        !is_nil(latest_cancelled_membership) ->
          Time.get_difference_in_days_with_epoch(latest_cancelled_membership.current_end)

        !is_nil(latest_paid_order) ->
          Time.get_difference_in_days_with_epoch(latest_paid_order.current_end)

        true ->
          nil
      end

    # If subscription_expired_in_days_ago > X days
    packages =
      cond do
        Enum.member?(@special_offers_for_paytm_broker_ids, broker_id) ->
          packagesForPaytmUsers =
            packages
            |> Enum.filter(fn package ->
              !is_nil(package.rules) and
                !is_nil(package.rules["expiry"]) and
                !is_nil(package.rules["expiry"]["gt"])
            end)

          if length(packagesForPaytmUsers) > 0, do: packagesForPaytmUsers, else: generic_packages

        !is_nil(subscription_expired_in_days_ago) ->
          packagesForRecentlyExpired =
            packages
            |> Enum.filter(fn package ->
              !is_nil(package.rules) and
                !is_nil(package.rules["expiry"]) and
                !is_nil(package.rules["expiry"]["gt"]) and
                subscription_expired_in_days_ago > package.rules["expiry"]["gt"]
            end)

          if length(packagesForRecentlyExpired) > 0, do: packagesForRecentlyExpired, else: generic_packages

        true ->
          generic_packages
      end

    # Do not display one month packages for old users, in Mumbai and Pune
    exclude_validity_in_days = if Enum.member?([1, 37], city_id) and not is_nil(latest_paid_order), do: [30], else: []

    packages
    |> Enum.filter(fn package -> !Enum.member?(exclude_validity_in_days, package.validity_in_days) end)
  end
end
