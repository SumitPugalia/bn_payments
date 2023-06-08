defmodule BnApis.Memberships.MatchPlusMembership do
  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query, warn: false
  alias BnApis.Repo
  alias BnApis.Posts
  alias BnApis.Helpers.Utils
  alias BnApis.Organizations.Broker
  alias BnApis.Accounts.Credential
  alias BnApis.Accounts.EmployeeCredential
  alias BnApis.Memberships.Membership
  alias BnApis.Memberships.MembershipOrder
  alias BnApis.Memberships.MatchPlusMembership
  alias BnApis.Accounts.OwnersBrokerEmployeeMapping
  alias BnApis.Helpers.Time
  alias BnApis.Accounts.EmployeeCredential
  alias BnApis.Places.Polygon
  alias BnApis.Orders.MatchPlusPackage

  @active_status_id 1
  @inactive_status_id 2
  @allowed_assigned_employee_editable_in_sec 48 * 60 * 60

  def get_active_status_id(), do: @active_status_id

  schema "match_plus_memberships" do
    field :status_id, :integer
    belongs_to(:broker, Broker)

    belongs_to(:latest_membership, Membership,
      foreign_key: :latest_membership_id,
      references: :id
    )

    has_many(:memberships, Membership, foreign_key: :match_plus_membership_id)

    timestamps()
  end

  @required [:broker_id, :status_id]
  @optional [:latest_membership_id]

  @doc false
  def changeset(match_plus_membership, attrs) do
    match_plus_membership
    |> cast(attrs, @required ++ @optional)
    |> validate_required(@required)
    |> foreign_key_constraint(:broker_id)
    |> foreign_key_constraint(:latest_membership_id)
  end

  def latest_membership_changeset(match_plus_membership, attrs) do
    match_plus_membership
    |> cast(attrs, [:latest_membership_id])
    |> validate_required([:latest_membership_id])
    |> foreign_key_constraint(:broker_id)
    |> foreign_key_constraint(:latest_membership_id)
  end

  def status_changeset(match_plus_membership, attrs) do
    match_plus_membership
    |> cast(attrs, [:status_id])
    |> validate_required([:status_id])
    |> foreign_key_constraint(:broker_id)
    |> foreign_key_constraint(:latest_membership_id)
  end

  def active_status_id() do
    @active_status_id
  end

  def inactive_status_id() do
    @inactive_status_id
  end

  def find_or_create!(broker_id) do
    match_plus_membership = Repo.get_by(MatchPlusMembership, broker_id: broker_id)

    if not is_nil(match_plus_membership) do
      match_plus_membership
    else
      MatchPlusMembership.create!(broker_id)
    end
  end

  def create!(broker_id) do
    status_id = @inactive_status_id

    ch =
      MatchPlusMembership.changeset(%MatchPlusMembership{}, %{
        broker_id: broker_id,
        status_id: status_id
      })

    Repo.insert!(ch)
  end

  def default_paytm_package(), do: %{number_of_months: 1, price_per_month: 999}

  def get_data(nil) do
    %{
      "mode" => "subscription",
      "is_match_plus_active" => false,
      "banner_text" => Posts.get_total_owner_posts() <> "+ owner properties are live",
      "banner_button_text" => "Subscribe",
      "display_renewal_banner" => true,
      # BLUE
      "banner_color" => "#cfe2f3"
    }
  end

  def get_data(match_plus_membership) do
    latest_active_membership = Membership.latest_membership_by_broker_by_status(match_plus_membership.broker_id, Membership.active_status())

    latest_cancelled_membership = Membership.latest_membership_by_broker_by_status(match_plus_membership.broker_id, Membership.reject_status())

    match_plus_membership = match_plus_membership |> Repo.preload([:latest_membership, :broker])
    city_id = match_plus_membership.broker.operating_city
    latest_membership = match_plus_membership.latest_membership

    data = %{
      "mode" => "subscription",
      "is_match_plus_active" => match_plus_membership.status_id == @active_status_id,
      "billing_start_at" => nil,
      "billing_end_at" => nil,
      "billing_end_at_in_days" => nil,
      "display_renewal_banner" => match_plus_membership.status_id != @active_status_id,
      "banner_text" => Posts.get_total_owner_posts(city_id) <> "+ owner properties are live",
      "banner_button_text" => "Subscribe",
      "banner_color" => "#cfe2f3",
      "next_billing_start_at" => nil,
      "next_billing_end_at" => nil,
      "special_offer" => false
    }

    cond do
      not is_nil(latest_active_membership) ->
        {next_billing_start_at, next_billing_end_at} = Membership.get_next_billing_dates(latest_active_membership)
        latest_active_membership_end_date_in_days = Utils.date_in_days(latest_active_membership.current_end)

        latest_paid_subscription_package =
          if not is_nil(latest_active_membership.match_plus_package),
            do: MatchPlusPackage.get_match_plus_package_data(latest_active_membership.match_plus_package),
            else: default_paytm_package()

        data
        |> Map.merge(%{
          "latest_paid_subscription_package" => latest_paid_subscription_package,
          "billing_start_at" => latest_active_membership.current_start,
          "billing_end_at" => latest_active_membership.current_end,
          "billing_end_at_in_days" => latest_active_membership_end_date_in_days,
          "next_billing_start_at" => next_billing_start_at,
          "next_billing_end_at" => next_billing_end_at
        })
        |> Map.merge(Membership.match_plus_attributes(latest_active_membership))

      not is_nil(latest_cancelled_membership) ->
        latest_cancelled_membership_end_date_in_days = Utils.date_in_days(latest_cancelled_membership.current_end)

        {banner_text, special_offer} =
          if Enum.member?([1, 37], city_id) and Time.get_difference_in_days_with_epoch(latest_cancelled_membership.current_end) > 30,
            do: {"🚫 Your Subsciption was expired. 🚫\n🎉 Check out new offers just for you! 🎉", true},
            else: {"Your Subscription has ended", false}

        latest_paid_subscription_package =
          if not is_nil(latest_cancelled_membership.match_plus_package),
            do: MatchPlusPackage.get_match_plus_package_data(latest_cancelled_membership.match_plus_package),
            else: default_paytm_package()

        data
        |> Map.merge(%{
          "latest_paid_subscription_package" => latest_paid_subscription_package,
          "billing_start_at" => latest_cancelled_membership.current_start,
          "billing_end_at" => latest_cancelled_membership.current_end,
          "billing_end_at_in_days" => latest_cancelled_membership_end_date_in_days,
          "special_offer" => special_offer,
          "banner_text" => banner_text,
          "banner_button_text" => "Renew",
          "banner_color" => "#F4CCCC"
        })
        |> Map.merge(Membership.match_plus_attributes(latest_cancelled_membership))

      not is_nil(latest_membership) ->
        data
        |> Map.merge(Membership.match_plus_attributes(latest_membership))

      true ->
        data
    end
  end

  def get_data_by_broker(broker) do
    Repo.get_by(MatchPlusMembership, broker_id: broker.id) |> MatchPlusMembership.get_data()
  end

  def update_latest_membership!(%MatchPlusMembership{} = match_plus_membership, latest_membership_id) do
    ch =
      MatchPlusMembership.latest_membership_changeset(match_plus_membership, %{
        latest_membership_id: latest_membership_id
      })

    Repo.update!(ch)
  end

  def update_status!(%MatchPlusMembership{} = match_plus_membership, status_id) do
    ch =
      MatchPlusMembership.status_changeset(match_plus_membership, %{
        status_id: status_id
      })

    Repo.update!(ch)
  end

  def verify_and_update_status(match_plus_membership) do
    latest_paid_membership = Membership.latest_paid_membership_by_broker(match_plus_membership.broker_id)
    active_memberships_count = Membership.active_memberships_count_by_broker(match_plus_membership.broker_id)

    status_id =
      if active_memberships_count > 0 do
        @active_status_id
      else
        current_timestamp = DateTime.utc_now() |> DateTime.to_unix()

        if !is_nil(latest_paid_membership) and current_timestamp <= latest_paid_membership.current_end do
          @active_status_id
        else
          @inactive_status_id
        end
      end

    MatchPlusMembership.update_status!(match_plus_membership, status_id)
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
      MatchPlusMembership
      |> join(:inner, [mps], s in Membership, on: mps.latest_membership_id == s.id)
      |> join(:inner, [mps, s], cred in Credential, on: mps.broker_id == cred.broker_id and cred.active == true)
      |> join(:inner, [mps, s, cred], bro in Broker, on: mps.broker_id == bro.id)

    query =
      if not is_nil(params["is_match_plus_active"]) do
        status_id = if params["is_match_plus_active"] == "true", do: 1, else: 2
        query |> where([mps, s, cred, bro], mps.status_id == ^status_id)
      else
        query
      end

    query =
      if not is_nil(params["membership_status"]) do
        query |> where([mps, s, cred, bro], s.status == ^params["membership_status"])
      else
        query
      end

    query =
      if not is_nil(params["phone_number"]) do
        query |> where([mps, s, cred, bro], cred.phone_number == ^params["phone_number"])
      else
        query
      end

    content_query =
      query
      |> order_by([mps, s, cred, bro], desc: s.inserted_at)
      |> limit(^size)
      |> offset(^((page - 1) * size))

    {query, content_query, page, size}
  end

  def fetch_memberships(params, _broker \\ nil) do
    {query, content_query, page, size} = MatchPlusMembership.filter_query(params)

    posts =
      content_query
      |> select([mps, s, cred, bro], %{
        phone_number: cred.phone_number,
        name: bro.name,
        is_match_plus_active:
          fragment(
            "
        CASE
          WHEN ? = 1
            THEN true
          ELSE
            false
        END
        ",
            mps.status_id
          ),
        is_membership_active:
          fragment(
            "
        CASE
          WHEN ? = 'active'
            THEN true
          ELSE
            false
        END
        ",
            s.status
          ),
        membership_status: s.status,
        paytm_subscription_id: s.paytm_subscription_id,
        membership_next_billing_charge_at: s.charge_at,
        membership_is_client_side_registration_successful: s.is_client_side_registration_successful,
        membership_billing_start_at: s.current_start,
        membership_billing_end_at: s.current_end,
        membership_created_at: s.inserted_at
      })
      |> Repo.all()

    total_count =
      query
      |> Repo.aggregate(:count, :id)

    has_more_memberships = page < Float.ceil(total_count / size)
    {posts, total_count, has_more_memberships}
  end

  def get_match_plus_count(params) do
    current_time = Time.now_to_epoch() |> div(1000)

    query =
      MatchPlusMembership
      |> join(:inner, [mps], s in Membership, on: mps.latest_membership_id == s.id)
      |> where([mps, s], s.status == ^Membership.active_status() or s.status == ^Membership.reject_status())
      |> where([mps, s], s.last_order_status == ^Membership.order_success())
      |> where([mps, s], s.current_start <= ^current_time and s.current_end >= ^current_time)
      |> join(:inner, [mps, s], b in Broker, on: b.id == mps.broker_id)

    query =
      if not is_nil(params["is_match_plus_active"]) do
        status_id = if params["is_match_plus_active"] == "true", do: 1, else: 2
        query |> where([mps, m, b], mps.status_id == ^status_id)
      else
        query
      end

    query =
      if not is_nil(params["city_id"]) do
        query |> where([mps, s, b], b.operating_city == ^params["city_id"])
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
      MatchPlusMembership
      |> join(:inner, [mps], s in Membership, on: mps.latest_membership_id == s.id)
      |> where([mps, s], s.status == ^Membership.active_status() or s.status == ^Membership.reject_status())
      |> join(:inner, [mps, s], cred in Credential, on: mps.broker_id == cred.broker_id and cred.active == true)
      |> join(:inner, [mps, s, cred], bro in Broker, on: mps.broker_id == bro.id)
      |> join(:left, [mps, s, cred, bro], obem in OwnersBrokerEmployeeMapping, on: obem.broker_id == mps.broker_id and obem.active == true)
      |> join(:left, [mps, s, cred, bro, obem], emp in EmployeeCredential, on: obem.employees_credentials_id == emp.id)
      |> join(:left, [mps, s, cred, bro, obem, emp], pl in Polygon, on: bro.polygon_id == pl.id)

    query =
      if not is_nil(params["autopay_failed"]) and params["autopay_failed"] == "true" do
        query
        |> where([mps, s], s.last_order_id != s.bn_order_id)
        |> where([mps, s], s.last_order_status != ^Membership.order_success())
      else
        query
        |> where([mps, s], s.last_order_status == ^Membership.order_success())
      end

    query =
      if not is_nil(params["is_match_plus_active"]) do
        status_id = if params["is_match_plus_active"] == "true", do: 1, else: 2
        query |> where([mps, s, cred, bro], mps.status_id == ^status_id)
      else
        query
      end

    query =
      if not is_nil(params["is_membership_currently_active"]) and params["is_membership_currently_active"] == "true" do
        current_time = Time.now_to_epoch() |> div(1000)
        query |> where([mps, s, cred, bro], s.current_start <= ^current_time and s.current_end >= ^current_time)
      else
        query
      end

    query =
      if not is_nil(params["membership_status"]) do
        query |> where([mps, s, cred, bro], s.status == fragment("UPPER(?)", ^params["membership_status"]))
      else
        query
      end

    query =
      if not is_nil(params["time_range_query"]) do
        {start_time, end_time} = Time.get_time_range(params["time_range_query"])

        if not is_nil(params["autopay_failed"]) and params["autopay_failed"] == "true" do
          query
          |> where(
            [mps, s, cred, bro],
            s.last_order_creation_date >= ^start_time and s.last_order_creation_date <= ^end_time
          )
        else
          query
          |> where(
            [mps, s, cred, bro],
            fragment("ROUND(extract(epoch from ?))", s.updated_at) >= ^start_time and
              fragment("ROUND(extract(epoch from ?))", s.updated_at) <= ^end_time
          )
        end
      else
        query
      end

    query =
      if not is_nil(params["phone_number"]) do
        broker_phone_number = params["phone_number"]
        formatted_query = "%#{String.downcase(String.trim(broker_phone_number))}%"
        query |> where([mps, s, cred, bro], fragment("LOWER(?) LIKE ?", cred.phone_number, ^formatted_query))
      else
        query
      end

    query =
      if not is_nil(params["broker_name"]) do
        broker_name = params["broker_name"]
        formatted_query = "%#{String.downcase(String.trim(broker_name))}%"
        query |> where([mps, s, cred, bro], fragment("LOWER(?) LIKE ?", bro.name, ^formatted_query))
      else
        query
      end

    query =
      if not is_nil(params["city_id"]) do
        query |> where([mps, s, cred, bro], bro.operating_city == ^params["city_id"])
      else
        query
      end

    query =
      if not is_nil(params["order_id"]) do
        query |> where([mps, s, cred, bro], s.bn_order_id == ^params["order_id"])
      else
        query
      end

    content_query =
      query
      |> order_by([mps, s, cred, bro], desc: s.last_order_creation_date)
      |> limit(^size)
      |> offset(^((page_no - 1) * size))

    {query, content_query, page_no, size}
  end

  def get_owner_panel_data(params) do
    {query, content_query, page_no, size} = MatchPlusMembership.filter_owner_panel_query(params)

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
      :membership_id,
      :membership_status,
      :pg_subscription_id,
      :payment_id,
      :payment_gateway,
      :membership_billing_start_at,
      :membership_billing_end_at,
      :membership_created_at,
      :payment_mode,
      :order_creation_date,
      :payment_status,
      :amount,
      :order_id,
      :autopay_worked_atleast_once,
      :broker_id,
      :assigned_employee_name,
      :assigned_employee_phone_number,
      :assigned_employee_email,
      :polygon
    ]

    query =
      MatchPlusMembership
      |> join(:inner, [mps], s in Membership, on: mps.latest_membership_id == s.id)
      |> where([mps, s], s.status == ^Membership.active_status() or s.status == ^Membership.reject_status())
      |> join(:inner, [mps, s], cred in Credential, on: mps.broker_id == cred.broker_id and cred.active == true)
      |> join(:inner, [mps, s, cred], bro in Broker, on: mps.broker_id == bro.id)
      |> join(:left, [mps, s, cred, bro], obem in OwnersBrokerEmployeeMapping, on: obem.broker_id == mps.broker_id and obem.active == true)
      |> join(:left, [mps, s, cred, bro, obem], emp in EmployeeCredential, on: obem.employees_credentials_id == emp.id)
      |> join(:left, [mps, s, cred, bro, obem, emp], pl in Polygon, on: bro.polygon_id == pl.id)

    query =
      if not is_nil(params["month"]) && not is_nil(params["year"]) do
        {start_time, end_time} = Time.get_time_range_for_month(params["month"], params["year"])

        query
        |> where(
          [mps, s, cred, bro],
          fragment("ROUND(extract(epoch from ?))", s.updated_at) >= ^start_time and
            fragment("ROUND(extract(epoch from ?))", s.updated_at) <= ^end_time
        )
      else
        query
      end

    records =
      query
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

  def get_new_and_cancelled_and_renewed_memberships_count(params) do
    query =
      MatchPlusMembership
      |> join(:inner, [mps], s in Membership, on: mps.latest_membership_id == s.id)
      |> join(:inner, [mps, s], cred in Credential, on: mps.broker_id == cred.broker_id and cred.active == true)
      |> join(:inner, [mps, s, cred], bro in Broker, on: mps.broker_id == bro.id)

    {start_time, end_time} = Time.get_time_range(params["time_range_query"])

    query =
      if not is_nil(params["city_id"]) do
        query |> where([mps, s, cred, bro], bro.operating_city == ^params["city_id"])
      else
        query
      end

    new_paytm_membs_count =
      query
      |> where([mps, s], s.status == ^Membership.active_status() or s.status == ^Membership.reject_status())
      |> where([mps, s], s.last_order_status == ^Membership.order_success())
      |> where([mps, s, cred, bro], s.current_start >= ^start_time)
      |> where([mps, s, cred, bro], s.current_start <= ^end_time)
      |> BnApis.Repo.aggregate(:count, :id)

    cancelled_paytm_membs_count =
      query
      |> where([mps, s], s.status == ^Membership.active_status() or s.status == ^Membership.reject_status())
      |> where([mps, s], s.last_order_status == ^Membership.order_success())
      |> where([mps, s, cred, bro], s.status == ^Membership.reject_status())
      |> where([mps, s, cred, bro], s.current_end >= ^start_time)
      |> where([mps, s, cred, bro], s.current_end <= ^end_time)
      |> BnApis.Repo.aggregate(:count, :id)

    renewed_paytm_membs_count =
      query
      |> join(:inner, [mps, s, cred, bro], m in Membership, on: m.match_plus_membership_id == mps.id)
      |> join(:inner, [mps, s, cred, bro, m], mo in MembershipOrder, on: mo.membership_id == m.id)
      |> where(
        [mps, s, cred, bro, m, mo],
        mo.order_status == ^Membership.order_success() and mo.order_id != m.bn_order_id
      )
      |> where(
        [mps, s, cred, bro, m, mo],
        mo.order_creation_date >= ^start_time and mo.order_creation_date <= ^end_time
      )
      |> BnApis.Repo.aggregate(:count, :id)

    not_renewed_paytm_membs_count =
      query
      |> join(:inner, [mps, s, cred, bro], m in Membership, on: m.match_plus_membership_id == mps.id)
      |> join(:inner, [mps, s, cred, bro, m], mo in MembershipOrder, on: mo.membership_id == m.id)
      |> where(
        [mps, s, cred, bro, m, mo],
        mo.order_status != ^Membership.order_success() and mo.order_id != m.bn_order_id
      )
      |> where(
        [mps, s, cred, bro, m, mo],
        mo.order_creation_date >= ^start_time and mo.order_creation_date <= ^end_time
      )
      |> BnApis.Repo.aggregate(:count, :id)

    {new_paytm_membs_count, cancelled_paytm_membs_count, renewed_paytm_membs_count, not_renewed_paytm_membs_count}
  end

  defp select_query(query) do
    query
    |> select([mps, s, cred, bro, obem, emp, pl], %{
      phone_number: cred.phone_number,
      name: bro.name,
      membership_id: s.id,
      membership_status: s.status,
      pg_subscription_id: s.paytm_subscription_id,
      payment_gateway: "Paytm",
      membership_billing_start_at: s.current_start,
      membership_billing_end_at: s.current_end,
      membership_created_at: s.created_at,
      payment_mode: s.payment_method,
      order_creation_date: s.last_order_creation_date,
      payment_status: s.last_order_status,
      amount: s.last_order_amount,
      order_id: s.last_order_id,
      txn_order_id: s.bn_order_id,
      autopay_worked_atleast_once:
        fragment(
          """
            CASE WHEN ? != ? AND ? = 'SUCCESS' THEN true ELSE false END
          """,
          s.bn_order_id,
          s.last_order_id,
          s.last_order_status
        ),
      broker_id: bro.id,
      assigned_employee: %{
        name: emp.name,
        phone_number: emp.phone_number,
        email: emp.email,
        editable: fragment("(EXTRACT(EPOCH FROM current_timestamp) - ?) < ?", s.created_at, @allowed_assigned_employee_editable_in_sec)
      },
      polygon: pl.name
    })
  end

  defp format(:assigned_employee_name, record), do: format(record |> Map.get(:assigned_employee) |> Map.get(:name))
  defp format(:assigned_employee_phone_number, record), do: format(record |> Map.get(:assigned_employee) |> Map.get(:phone_number))
  defp format(:assigned_employee_phone_email, record), do: format(record |> Map.get(:assigned_employee) |> Map.get(:email))
  defp format(:payment_id, record), do: format(record |> Map.get(:txn_order_id))

  defp format(epoch_timestamp_columns, record)
       when epoch_timestamp_columns in [
              :membership_billing_start_at,
              :membership_billing_end_at,
              :membership_created_at,
              :order_creation_date
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
