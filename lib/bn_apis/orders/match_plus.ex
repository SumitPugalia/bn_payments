defmodule BnApis.Orders.MatchPlus do
  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query, warn: false
  alias BnApis.Repo
  alias BnApis.Posts
  alias BnApis.Helpers.Utils
  alias BnApis.Organizations.Broker
  alias BnApis.Accounts.Credential
  alias BnApis.Orders.Order
  alias BnApis.Orders.OrderPayment
  alias BnApis.Orders.MatchPlus
  alias BnApis.Helpers.ApplicationHelper
  alias BnApis.Accounts.OwnersBrokerEmployeeMapping
  alias BnApis.Helpers.Time
  alias BnApis.Accounts.EmployeeCredential
  alias BnApis.Places.Polygon
  alias BnApis.Orders.MatchPlusPackage
  alias BnApis.Helpers.Utils

  @active_status_id 1
  @inactive_status_id 2

  @currency "INR"
  @paid_order_status "paid"
  @allowed_assigned_employee_editable_in_sec 48 * 60 * 60

  def get_active_status_id(), do: @active_status_id

  schema "match_plus" do
    field :status_id, :integer
    belongs_to(:broker, Broker)

    belongs_to(:latest_order, Order,
      foreign_key: :latest_order_id,
      references: :id
    )

    belongs_to(:latest_paid_order, Order,
      foreign_key: :latest_paid_order_id,
      references: :id
    )

    has_many(:orders, Order, foreign_key: :match_plus_id)

    timestamps()
  end

  @required [:broker_id, :status_id]
  @optional [:latest_order_id, :latest_paid_order_id]

  @doc false
  def changeset(match_plus, attrs) do
    match_plus
    |> cast(attrs, @required ++ @optional)
    |> validate_required(@required)
    |> foreign_key_constraint(:broker_id)
    |> foreign_key_constraint(:latest_order_id)
    |> unique_constraint(:broker_id)
  end

  def latest_order_changeset(match_plus, attrs) do
    match_plus
    |> cast(attrs, [:latest_order_id])
    |> validate_required([:latest_order_id])
    |> foreign_key_constraint(:broker_id)
    |> foreign_key_constraint(:latest_order_id)
  end

  def latest_paid_order_changeset(match_plus, attrs) do
    match_plus
    |> cast(attrs, [:latest_paid_order_id])
    |> foreign_key_constraint(:broker_id)
    |> foreign_key_constraint(:latest_paid_order_id)
  end

  def status_changeset(match_plus, attrs) do
    match_plus
    |> cast(attrs, [:status_id])
    |> validate_required([:status_id])
    |> foreign_key_constraint(:broker_id)
    |> foreign_key_constraint(:latest_order_id)
  end

  def active_status_id() do
    @active_status_id
  end

  def inactive_status_id() do
    @inactive_status_id
  end

  def price() do
    ApplicationHelper.get_match_plus_price() * 100
  end

  def currency() do
    @currency
  end

  def find_or_create!(broker_id) do
    match_plus = Repo.get_by(MatchPlus, broker_id: broker_id)

    if not is_nil(match_plus) do
      match_plus
    else
      MatchPlus.create!(broker_id)
    end
  end

  def create!(broker_id) do
    status_id = 2

    ch =
      MatchPlus.changeset(%MatchPlus{}, %{
        broker_id: broker_id,
        status_id: status_id
      })

    Repo.insert!(ch)
  end

  def get_data(nil) do
    %{
      "mode" => "package",
      "is_match_plus_active" => false,
      "banner_text" => Posts.get_total_owner_posts() <> "+ owner properties are live",
      "banner_button_text" => "Subscribe",
      "display_renewal_banner" => true,
      # BLUE
      "banner_color" => "#cfe2f3"
    }
  end

  def get_data(match_plus) do
    match_plus = match_plus |> Repo.preload([:broker])
    city_id = match_plus.broker.operating_city
    latest_paid_order = match_plus.latest_paid_order |> Repo.preload([:match_plus_package])
    latest_order = match_plus.latest_order
    is_match_plus_active = match_plus.status_id == 1

    {banner_text, banner_button_text, banner_color} = {
      Posts.get_total_owner_posts(city_id) <> "+ owner properties are live",
      "Subscribe",
      # BLUE
      "#cfe2f3"
    }

    data = %{
      "mode" => "package",
      "is_match_plus_active" => is_match_plus_active,
      "billing_start_at" => nil,
      "billing_end_at" => nil,
      "billing_end_at_in_days" => nil,
      "display_renewal_banner" => true,
      "banner_text" => banner_text,
      "banner_button_text" => banner_button_text,
      "banner_color" => banner_color,
      "next_billing_start_at" => nil,
      "next_billing_end_at" => nil,
      "order_id" => nil,
      "razorpay_order_id" => nil,
      "pg_order_id" => nil,
      "payment_gateway" => "razorpay",
      "order_is_client_side_payment_successful" => false,
      "order_status" => nil,
      "order_created_at" => nil,
      "latest_paid_order_for_number_of_months" => nil,
      "has_latest_paid_order" => not is_nil(latest_paid_order)
    }

    data =
      cond do
        is_nil(latest_order) ->
          data

        is_nil(latest_paid_order) ->
          data
          |> Map.merge(%{
            "order_id" => latest_order.id,
            "razorpay_order_id" => latest_order.razorpay_order_id,
            "pg_order_id" => latest_order.razorpay_order_id,
            "order_is_client_side_payment_successful" => latest_order.is_client_side_payment_successful,
            "order_status" => latest_order.status,
            "order_created_at" => latest_order.inserted_at
          })

        true ->
          billing_end_at_in_days = Utils.date_in_days(latest_paid_order.current_end)
          display_renewal_banner = true

          next_billing_start_at = Order.next_billing_start_at(latest_paid_order)
          next_billing_end_at = Order.next_billing_end_at(next_billing_start_at)

          # override
          is_client_side_payment_successful =
            if match_plus.status_id != 1 and latest_order.is_client_side_payment_successful == true and
                 latest_order.status == "paid" do
              false
            else
              latest_order.is_client_side_payment_successful
            end

          {banner_text, banner_button_text, banner_color} =
            cond do
              is_match_plus_active == true and billing_end_at_in_days == 1 ->
                {
                  "Your Subscription is ending today",
                  "Renew",
                  # GREEN
                  "#F4CCCC"
                }

              is_match_plus_active == true and billing_end_at_in_days <= 5 ->
                {
                  "Your Subscription is ending in #{billing_end_at_in_days} days",
                  "Renew",
                  # GREEN
                  "#F4CCCC"
                }

              is_match_plus_active == true ->
                {
                  "Your Subscription will be active for #{billing_end_at_in_days} days",
                  "Extend",
                  # GREEN
                  "#78EDA9"
                }

              is_match_plus_active == false and not is_nil(latest_paid_order) and Time.get_difference_in_days_with_epoch(latest_paid_order.current_end) > 30 and
                  Enum.member?([1, 37], city_id) ->
                {
                  "🚫 Your Subsciption was expired. 🚫\n🎉 Check out new offers just for you! 🎉",
                  "Renew",
                  # RED
                  "#F4CCCC"
                }

              is_match_plus_active == false and not is_nil(latest_paid_order) ->
                {
                  "Your Subscription has ended",
                  "Renew",
                  # RED
                  "#F4CCCC"
                }

              true ->
                {
                  Posts.get_total_owner_posts(city_id) <> "+ owner properties are live",
                  "Subscribe",
                  # BLUE
                  "#cfe2f3"
                }
            end

          latest_paid_order_for_number_of_months =
            if not is_nil(latest_paid_order.match_plus_package) do
              floor(latest_paid_order.match_plus_package.validity_in_days / MatchPlusPackage.days_in_month())
            else
              nil
            end

          latest_paid_order_package = MatchPlusPackage.get_match_plus_package_data(latest_paid_order.match_plus_package)

          allow_extension = if is_nil(billing_end_at_in_days) or billing_end_at_in_days <= 30, do: true, else: false

          data
          |> Map.merge(%{
            "latest_paid_order_package" => latest_paid_order_package,
            "latest_paid_order_for_number_of_months" => latest_paid_order_for_number_of_months,
            "billing_start_at" => latest_paid_order.current_start,
            "billing_end_at" => latest_paid_order.current_end,
            "billing_end_at_in_days" => billing_end_at_in_days,
            "allow_extension" => allow_extension,
            "display_renewal_banner" => display_renewal_banner,
            "banner_text" => banner_text,
            "banner_button_text" => banner_button_text,
            "banner_color" => banner_color,
            "next_billing_start_at" => next_billing_start_at,
            "next_billing_end_at" => next_billing_end_at,
            "order_id" => latest_order.id,
            ## Legacy Key
            "razorpay_order_id" => latest_order.razorpay_order_id,
            ## New Key
            "pg_order_id" => latest_order.razorpay_order_id,
            "payment_gateway" => "razorpay",
            "order_is_client_side_payment_successful" => is_client_side_payment_successful,
            "order_status" => latest_order.status,
            "order_created_at" => latest_order.inserted_at
          })
      end

    city_offer = if city_id in ApplicationHelper.diwali_offer_applied_cities(), do: true, else: false

    if city_offer == true do
      {display_offer_banner, allow_extension} =
        if is_match_plus_active and not is_nil(latest_paid_order) do
          # GMT Wednesday, 19 October 2022 00:00:00
          order_creation_time = latest_paid_order.inserted_at |> Time.naive_to_epoch_in_sec()

          if order_creation_time >= ApplicationHelper.offer_start_time_epoch() do
            {false, false}
          else
            {true, true}
          end
        else
          {true, true}
        end

      data
      |> Map.merge(%{
        "display_offer_banner" => display_offer_banner,
        "allow_extension" => allow_extension
      })
    else
      data
    end
  end

  def get_latest_match_plus(match_plus, user_package) do
    cond do
      match_plus["is_match_plus_active"] and user_package["is_match_plus_active"] ->
        if match_plus["billing_end_at"] > user_package["billing_end_at"], do: match_plus, else: user_package

      match_plus["is_match_plus_active"] ->
        match_plus

      user_package["is_match_plus_active"] ->
        user_package

      true ->
        match_plus
    end
  end

  def get_data_by_broker(broker) do
    MatchPlus
    |> where([mp], mp.broker_id == ^broker.id)
    |> preload([:latest_order, :latest_paid_order])
    |> Repo.one()
    |> MatchPlus.get_data()
  end

  def update_latest_order!(%MatchPlus{} = match_plus, latest_order_id) do
    ch =
      MatchPlus.latest_order_changeset(match_plus, %{
        latest_order_id: latest_order_id
      })

    Repo.update!(ch)
  end

  def update_latest_paid_order!(%MatchPlus{} = match_plus, latest_paid_order_id) do
    ch =
      MatchPlus.latest_paid_order_changeset(match_plus, %{
        latest_paid_order_id: latest_paid_order_id
      })

    Repo.update!(ch)
  end

  def update_status!(%MatchPlus{} = match_plus, status_id) do
    ch =
      MatchPlus.status_changeset(match_plus, %{
        status_id: status_id
      })

    Repo.update!(ch)
  end

  def verify_and_update_status(match_plus) do
    latest_paid_order = Order.get_latest_paid_order_of_a_broker(match_plus.broker_id)

    status_id =
      if is_nil(latest_paid_order) do
        @inactive_status_id
      else
        current_timestamp = DateTime.utc_now() |> DateTime.to_unix()

        if !is_nil(latest_paid_order.current_end) and
             current_timestamp <= latest_paid_order.current_end do
          @active_status_id
        else
          @inactive_status_id
        end
      end

    MatchPlus.update_status!(match_plus, status_id)
    latest_paid_order_id = if is_nil(latest_paid_order), do: nil, else: latest_paid_order.id
    MatchPlus.update_latest_paid_order!(match_plus, latest_paid_order_id)
  end

  def filter_query(params) do
    page =
      case not is_nil(params["p"]) and Integer.parse(params["p"]) do
        {val, _} -> val
        _ -> 1
      end

    size =
      case not is_nil(params["size"]) and Integer.parse(params["size"]) do
        {val, _} -> val
        _ -> 10
      end

    query =
      MatchPlus
      |> join(:left, [mp], obem in OwnersBrokerEmployeeMapping, on: obem.broker_id == mp.broker_id and obem.active == true)

    query =
      if not is_nil(params["broker_id"]) do
        broker_id = if is_binary(params["broker_id"]), do: params["broker_id"] |> String.trim() |> String.to_integer(), else: params["broker_id"]

        query
        |> where([mp], mp.broker_id == ^broker_id)
      else
        query
      end

    query =
      if not is_nil(params["phone_number"]) do
        query
        |> join(:inner, [mp, obem], cred in Credential, on: mp.broker_id == cred.broker_id and cred.active == true)
        |> where([mp, obem, cred], cred.phone_number == ^params["phone_number"])
      else
        query
      end

    query =
      if not is_nil(params["city_id"]) do
        city_id = Utils.parse_to_integer(params["city_id"])

        query
        |> join(:inner, [mp, obem], b in Broker, on: mp.broker_id == b.id)
        |> join(:inner, [mp, obem, b], cred in Credential, on: cred.broker_id == b.id and cred.active == true)
        |> where([mp, obem, b, cred], not is_nil(b.operating_city) and b.operating_city == ^city_id)
      else
        query
      end

    expiry_query = query

    query =
      if not is_nil(params["is_match_plus_active"]) do
        status_id = if params["is_match_plus_active"] == "true", do: 1, else: 2
        query |> where([mp], mp.status_id == ^status_id)
      else
        query
      end

    query =
      if not is_nil(params["employee_id"]) do
        employee_id = if is_binary(params["employee_id"]), do: String.to_integer(params["employee_id"]), else: params["employee_id"]

        query |> where([mp, obem], obem.employees_credentials_id == ^employee_id)
      else
        query
      end

    query =
      if not is_nil(params["expiry_date"]) do
        now = Timex.now() |> Timex.Timezone.convert("Asia/Kolkata")
        {expiry, _} = Integer.parse(params["expiry_date"])
        expiry_day_start = now |> Timex.shift(days: expiry) |> Timex.beginning_of_day() |> DateTime.to_unix()
        expiry_day_end = now |> Timex.shift(days: expiry) |> Timex.end_of_day() |> DateTime.to_unix()

        if expiry == -3 do
          query
          |> join(:inner, [mp, ...], ord in Order, on: mp.latest_paid_order_id == ord.id)
          |> where([mp, ..., ord], ord.status == ^@paid_order_status and ord.current_end <= ^expiry_day_start)
        else
          if expiry == 6 do
            query
            |> join(:inner, [mp, ...], ord in Order, on: mp.latest_paid_order_id == ord.id)
            |> where([mp, ..., ord], ord.status == ^@paid_order_status and ord.current_end >= ^expiry_day_start)
          else
            query
            |> join(:inner, [mp, ...], ord in Order, on: mp.latest_paid_order_id == ord.id)
            |> where(
              [mp, ..., ord],
              ord.status == ^@paid_order_status and ^expiry_day_end >= ord.current_end and
                ord.current_end >= ^expiry_day_start
            )
          end
        end
      else
        query
      end

    content_query =
      query
      |> order_by([mp], desc: mp.updated_at)
      |> limit(^size)
      |> offset(^((page - 1) * size))

    {query, content_query, page, size, expiry_query}
  end

  def fetch_orders(params) do
    {query, content_query, page, size, expiry_query} = MatchPlus.filter_query(params)

    posts =
      content_query
      |> Repo.all()
      |> Repo.preload([:latest_order, :latest_paid_order, broker: [:credentials]])
      |> Enum.map(fn match_plus ->
        broker = match_plus.broker
        credential = match_plus.broker.credentials |> List.last()

        obem =
          OwnersBrokerEmployeeMapping
          |> where([obm], obm.broker_id == ^match_plus.broker_id and obm.active == ^true)
          |> Repo.all()
          |> Repo.preload([:employees_credentials])
          |> List.last()

        order =
          if is_nil(match_plus.latest_paid_order),
            do: match_plus.latest_order,
            else: match_plus.latest_paid_order

        MatchPlus.get_data(match_plus)
        |> Map.merge(%{
          broker_id: match_plus.broker_id,
          name: broker.name,
          phone_number: credential.phone_number,
          assigned_employee:
            if(not is_nil(obem),
              do: %{
                name: obem.employees_credentials.name,
                phone_number: obem.employees_credentials.phone_number,
                email: obem.employees_credentials.email
              },
              else: nil
            ),
          order_id: if(not is_nil(order), do: order.id, else: nil),
          order_status: if(not is_nil(order), do: order.status, else: nil),
          order_created_at: if(not is_nil(order), do: order.inserted_at, else: nil)
        })
      end)

    expiry_wise_count =
      if not is_nil(params["filter_by_expiry"]) do
        now = Timex.now() |> Timex.Timezone.convert("Asia/Kolkata") |> Timex.beginning_of_day()
        day_at_minus_3 = now |> Timex.shift(days: -3) |> DateTime.to_unix()
        day_at_minus_2 = now |> Timex.shift(days: -2) |> DateTime.to_unix()
        day_at_minus_2_end = now |> Timex.shift(days: -2) |> Timex.end_of_day() |> DateTime.to_unix()
        day_at_minus_1 = now |> Timex.shift(days: -1) |> DateTime.to_unix()
        day_at_minus_1_end = now |> Timex.shift(days: -1) |> Timex.end_of_day() |> DateTime.to_unix()
        day_at_minus_0 = now |> Timex.shift(days: 0) |> DateTime.to_unix()
        day_at_minus_0_end = now |> Timex.shift(days: 0) |> Timex.end_of_day() |> DateTime.to_unix()
        day_at_plus_1 = now |> Timex.shift(days: 1) |> DateTime.to_unix()
        day_at_plus_1_end = now |> Timex.shift(days: 1) |> Timex.end_of_day() |> DateTime.to_unix()
        day_at_plus_2 = now |> Timex.shift(days: 2) |> DateTime.to_unix()
        day_at_plus_2_end = now |> Timex.shift(days: 2) |> Timex.end_of_day() |> DateTime.to_unix()
        day_at_plus_3 = now |> Timex.shift(days: 3) |> DateTime.to_unix()
        day_at_plus_3_end = now |> Timex.shift(days: 3) |> Timex.end_of_day() |> DateTime.to_unix()
        day_at_plus_4 = now |> Timex.shift(days: 4) |> DateTime.to_unix()
        day_at_plus_4_end = now |> Timex.shift(days: 4) |> Timex.end_of_day() |> DateTime.to_unix()
        day_at_plus_5 = now |> Timex.shift(days: 5) |> DateTime.to_unix()
        day_at_plus_5_end = now |> Timex.shift(days: 5) |> Timex.end_of_day() |> DateTime.to_unix()
        day_at_plus_6 = now |> Timex.shift(days: 6) |> DateTime.to_unix()

        expiry_query
        |> join(:inner, [mp], o in Order, on: mp.latest_paid_order_id == o.id)
        |> where([mp, ..., o], o.status == ^"paid")
        |> select([mp, ..., o], %{
          id: o.id,
          end_date:
            fragment(
              """
                CASE WHEN (? < ?) THEN -3
                WHEN (? >= ? AND ? >= ?) THEN -2
                WHEN (? >= ? AND ? >= ?) THEN -1
                WHEN (? >= ? AND ? >= ?) THEN 0
                WHEN (? >= ? AND ? >= ?) THEN 1
                WHEN (? >= ? AND ? >= ?) THEN 2
                WHEN (? >= ? AND ? >= ?) THEN 3
                WHEN (? >= ? AND ? >= ?) THEN 4
                WHEN (? >= ? AND ? >= ?) THEN 5
                WHEN (? < ?) THEN 6
                ELSE 20 END as diff
              """,
              o.current_end,
              ^day_at_minus_3,
              ^day_at_minus_2_end,
              o.current_end,
              o.current_end,
              ^day_at_minus_2,
              ^day_at_minus_1_end,
              o.current_end,
              o.current_end,
              ^day_at_minus_1,
              ^day_at_minus_0_end,
              o.current_end,
              o.current_end,
              ^day_at_minus_0,
              ^day_at_plus_1_end,
              o.current_end,
              o.current_end,
              ^day_at_plus_1,
              ^day_at_plus_2_end,
              o.current_end,
              o.current_end,
              ^day_at_plus_2,
              ^day_at_plus_3_end,
              o.current_end,
              o.current_end,
              ^day_at_plus_3,
              ^day_at_plus_4_end,
              o.current_end,
              o.current_end,
              ^day_at_plus_4,
              ^day_at_plus_5_end,
              o.current_end,
              o.current_end,
              ^day_at_plus_5,
              ^day_at_plus_6,
              o.current_end
            )
        })
        |> Repo.all()
        |> Enum.reduce(%{}, fn data, acc ->
          if not is_nil(acc[data.end_date]) do
            Map.put(acc, data.end_date, acc[data.end_date] + 1)
          else
            Map.put(acc, data.end_date, 1)
          end
        end)
      else
        %{}
      end

    total_count =
      query
      |> Repo.aggregate(:count, :id)

    has_more_orders = page < Float.ceil(total_count / size)
    {posts, total_count, has_more_orders, expiry_wise_count}
  end

  def get_match_plus_count(params) do
    current_time = Time.now_to_epoch() |> div(1000)

    query =
      MatchPlus
      |> join(:inner, [m], b in Broker, on: b.id == m.broker_id)
      |> join(:inner, [m, b], o in Order, on: o.id == m.latest_paid_order_id)
      |> where([m, b, o], o.status == ^Order.paid_status())
      |> where([m, b, o], o.current_start <= ^current_time and o.current_end >= ^current_time)

    query =
      if not is_nil(params["is_match_plus_active"]) do
        status_id = if params["is_match_plus_active"] == "true", do: 1, else: 2
        query |> where([m, b], m.status_id == ^status_id)
      else
        query
      end

    query =
      if not is_nil(params["city_id"]) do
        query |> where([m, b], b.operating_city == ^params["city_id"])
      else
        query
      end

    query
    |> Repo.aggregate(:count, :id)
  end

  def filter_owner_panel_query(params) do
    page_no = (params["p"] || "1") |> String.to_integer()
    size = (params["size"] || "10") |> String.to_integer()

    query =
      MatchPlus
      |> join(:inner, [mp], ord in Order, on: mp.latest_paid_order_id == ord.id)
      |> where([mp, ord], ord.status == ^Order.paid_status())
      |> join(:inner, [mp, ord], op in OrderPayment, on: op.order_id == ord.id)
      |> where([mp, ord, op], op.razorpay_payment_status == ^OrderPayment.captured_status())
      |> join(:inner, [mp, ord, op], cred in Credential, on: mp.broker_id == cred.broker_id and cred.active == true)
      |> join(:inner, [mp, ord, op, cred], bro in Broker, on: mp.broker_id == bro.id)
      |> join(:left, [mps, s, op, cred, bro], obem in OwnersBrokerEmployeeMapping, on: obem.broker_id == mps.broker_id and obem.active == true)
      |> join(:left, [mps, s, op, cred, bro, obem], emp in EmployeeCredential, on: obem.employees_credentials_id == emp.id)
      |> join(:left, [mps, s, op, cred, bro, obem, emp], pl in Polygon, on: bro.polygon_id == pl.id)

    query =
      if not is_nil(params["is_match_plus_active"]) do
        status_id = if params["is_match_plus_active"] == "true", do: 1, else: 2
        query |> where([mp, ord, op, cred, bro], mp.status_id == ^status_id)
      else
        query
      end

    query =
      if not is_nil(params["is_membership_currently_active"]) and params["is_membership_currently_active"] == "true" do
        current_time = Time.now_to_epoch() |> div(1000)

        query
        |> where([mp, ord, op, cred, bro], ord.current_start <= ^current_time and ord.current_end >= ^current_time)
      else
        query
      end

    query =
      if not is_nil(params["city_id"]) do
        query |> where([mp, ord, op, cred, bro], bro.operating_city == ^params["city_id"])
      else
        query
      end

    query =
      if not is_nil(params["order_id"]) do
        query |> where([mp, ord, op, cred, bro], ord.id == ^params["order_id"])
      else
        query
      end

    query =
      if not is_nil(params["phone_number"]) do
        broker_phone_number = params["phone_number"]
        formatted_query = "%#{String.downcase(String.trim(broker_phone_number))}%"
        query |> where([mp, ord, op, cred, bro], fragment("LOWER(?) LIKE ?", cred.phone_number, ^formatted_query))
      else
        query
      end

    query =
      if not is_nil(params["time_range_query"]) do
        {start_time, end_time} = Time.get_time_range(params["time_range_query"])

        query
        |> where(
          [mp, ord, op, cred, bro],
          fragment("ROUND(extract(epoch from ?))", ord.updated_at) >= ^start_time and
            fragment("ROUND(extract(epoch from ?))", ord.updated_at) <= ^end_time
        )
      else
        query
      end

    query =
      if not is_nil(params["broker_name"]) do
        broker_name = params["broker_name"]
        formatted_query = "%#{String.downcase(String.trim(broker_name))}%"
        query |> where([mp, ord, op, cred, bro], fragment("LOWER(?) LIKE ?", bro.name, ^formatted_query))
      else
        query
      end

    content_query =
      query
      |> order_by([mp, ord, op, cred, bro], desc: ord.updated_at)
      |> limit(^size)
      |> offset(^((page_no - 1) * size))

    {query, content_query, page_no, size}
  end

  def get_owner_panel_data(params) do
    {query, content_query, page_no, size} = MatchPlus.filter_owner_panel_query(params)

    posts =
      content_query
      |> select_query()
      |> Repo.all()

    total_count =
      query
      |> Repo.aggregate(:count, :id)

    has_more_memberships = page_no < Float.ceil(total_count / size)
    {posts, total_count, has_more_memberships}
  end

  def build_export_query(params) do
    columns = [
      :phone_number,
      :name,
      :membership_status,
      :pg_subscription_id,
      :payment_id,
      :payment_gateway,
      :membership_billing_start_at,
      :membership_billing_end_at,
      :membership_created_at,
      :payment_status,
      :payment_mode,
      :order_id,
      :broker_id,
      :amount,
      :assigned_employee_name,
      :assigned_employee_phone_number,
      :assigned_employee_email,
      :polygon
    ]

    query =
      MatchPlus
      |> join(:inner, [mp], ord in Order, on: mp.latest_paid_order_id == ord.id)
      |> where([mp, ord], ord.status == ^Order.paid_status())
      |> join(:inner, [mp, ord], op in OrderPayment, on: op.order_id == ord.id)
      |> where([mp, ord, op], op.razorpay_payment_status == ^OrderPayment.captured_status())
      |> join(:inner, [mp, ord, op], cred in Credential, on: mp.broker_id == cred.broker_id and cred.active == true)
      |> join(:inner, [mp, ord, op, cred], bro in Broker, on: mp.broker_id == bro.id)
      |> join(:left, [mps, s, op, cred, bro], obem in OwnersBrokerEmployeeMapping, on: obem.broker_id == mps.broker_id and obem.active == true)
      |> join(:left, [mps, s, op, cred, bro, obem], emp in EmployeeCredential, on: obem.employees_credentials_id == emp.id)
      |> join(:left, [mps, s, op, cred, bro, obem, emp], pl in Polygon, on: bro.polygon_id == pl.id)

    query =
      if not is_nil(params["month"]) && not is_nil(params["year"]) do
        {start_time, end_time} = Time.get_time_range_for_month(params["month"], params["year"])

        query
        |> where(
          [mp, ord, op, cred, bro],
          fragment("ROUND(extract(epoch from ?))", op.updated_at) >= ^start_time and
            fragment("ROUND(extract(epoch from ?))", op.updated_at) <= ^end_time
        )
      else
        query
      end

    records =
      query
      |> order_by([mp, ord, op, cred, bro], desc: ord.updated_at)
      |> select_query()
      |> Repo.all()

    [columns]
    |> Stream.concat(
      records
      |> Stream.map(fn record ->
        Enum.map(columns, fn column ->
          format(column, record)
        end)
      end)
    )
    |> CSV.encode()
    |> Enum.to_list()
    |> to_string()
  end

  def get_new_and_cancelled_subscriptions_count(params) do
    query =
      MatchPlus
      |> join(:inner, [mp], ord in Order, on: mp.latest_paid_order_id == ord.id)
      |> where([mp, ord], ord.status == ^Order.paid_status())
      |> join(:inner, [mp, ord], cred in Credential, on: mp.broker_id == cred.broker_id and cred.active == true)
      |> join(:inner, [mp, ord, cred], bro in Broker, on: mp.broker_id == bro.id)

    {start_time, end_time} =
      if not is_nil(params["time_range_query"]) do
        Time.get_time_range(params["time_range_query"])
      else
        {0, Time.now_to_epoch() |> div(1000)}
      end

    query =
      if not is_nil(params["city_id"]) do
        query |> where([mps, s, cred, bro], bro.operating_city == ^params["city_id"])
      else
        query
      end

    new_razorpay_membs_count =
      query
      |> where([mp, ord, cred, bro], ord.current_start >= ^start_time)
      |> where([mp, ord, cred, bro], ord.current_start <= ^end_time)
      |> BnApis.Repo.aggregate(:count, :id)

    cancelled_razorpay_membs_count = 0

    {new_razorpay_membs_count, cancelled_razorpay_membs_count}
  end

  defp select_query(query) do
    query
    |> select([mp, ord, op, cred, bro, obem, emp, pl], %{
      phone_number: cred.phone_number,
      name: bro.name,
      membership_status: "ACTIVE",
      pg_subscription_id: ord.razorpay_order_id,
      txn_order_id: op.razorpay_payment_id,
      payment_gateway: "Razorpay",
      membership_billing_start_at: ord.current_start,
      membership_billing_end_at: ord.current_end,
      membership_created_at: op.created_at,
      payment_status: ord.status,
      payment_mode: "UNKNOWN",
      order_id: ord.razorpay_order_id,
      broker_id: bro.id,
      amount: ord.amount,
      assigned_employee: %{
        name: emp.name,
        phone_number: emp.phone_number,
        email: emp.email,
        ## it is null when ord.created_at is null
        editable: fragment("(EXTRACT(EPOCH FROM current_timestamp) - ?) < ?", op.created_at, @allowed_assigned_employee_editable_in_sec)
      },
      polygon: pl.name
    })
  end

  defp format(:assigned_employee_name, record), do: format(record |> Map.get(:assigned_employee) |> Map.get(:name))
  defp format(:assigned_employee_phone_number, record), do: format(record |> Map.get(:assigned_employee) |> Map.get(:phone_number))
  defp format(:assigned_employee_phone_email, record), do: format(record |> Map.get(:assigned_employee) |> Map.get(:email))
  defp format(:amount, record), do: format(record |> Map.get(:amount) |> div(100))
  defp format(:payment_id, record), do: format(record |> Map.get(:txn_order_id))

  defp format(epoch_timestamp_columns, record)
       when epoch_timestamp_columns in [
              :membership_billing_start_at,
              :membership_billing_end_at,
              :membership_created_at
            ] do
    epoch_timestamp =
      case record |> Map.get(epoch_timestamp_columns) do
        nil -> nil
        timestamp -> timestamp * 1000
      end

    format(epoch_timestamp |> Time.epoch_to_naive())
  end

  defp format(column, record), do: format(record |> Map.get(column))

  defp format(%NaiveDateTime{} = value), do: value |> Timex.Timezone.convert("Etc/UTC") |> Timex.Timezone.convert("Asia/Kolkata") |> Timex.format!("%I:%M %P, %d %b, %Y", :strftime)
  defp format(value) when is_map(value), do: Jason.encode!(value)
  defp format(value) when is_list(value), do: Jason.encode!(value)
  defp format(value), do: String.replace(~s(#{value}), ~s("), "")
end
