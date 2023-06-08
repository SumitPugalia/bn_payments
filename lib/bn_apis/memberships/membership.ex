defmodule BnApis.Memberships.Membership do
  use Ecto.Schema
  import Ecto.Query
  import Ecto.Changeset
  alias BnApis.Repo
  alias BnApis.Helpers.ApplicationHelper
  alias BnApis.Memberships.Membership
  alias BnApis.Memberships.MembershipStatus
  alias BnApis.Memberships.MembershipOrder
  alias BnApis.Memberships.MatchPlusMembership
  alias BnApis.Orders.MatchPlusPackage
  alias BnApis.Organizations.Broker

  # possible statuses: Possible Values: INIT, ACTIVE, REJECT, IN_AUTHORIZATION, AUTHORIZED, AUTHORIZATION_FAILED, EXPIRED, CLOSED, SUSPENDED
  @created_status "INIT"
  @authenticated_status "AUTHORIZED"
  @authorization_failed_status "AUTHORIZATION_FAILED"
  @active_status "ACTIVE"
  @suspended_status "SUSPENDED"
  @closed_status "CLOSED"
  @reject_status "REJECT"

  @default_txn_amount "1.00"

  @dummy_amount_monthly 999.0
  @dummy_amount_quarterly 2699.0
  @dummy_amount_half_yearly 4999.0
  @dummy_amount_yearly 8999.0

  @order_success "SUCCESS"

  schema "memberships" do
    field(:match_plus_membership_id, :integer)
    field(:paytm_subscription_id, :string)
    field(:bn_order_id, :string)
    field(:created_at, :integer)
    field(:bn_customer_id, :string)
    field(:status, :string)
    field(:last_order_id, :string)
    field(:last_order_status, :string)
    field(:last_order_creation_date, :integer)
    field(:last_order_amount, :string)
    field(:subscription_amount, :string)
    field(:short_url, :string)
    field(:payment_method, :string)
    field(:start_at, :integer)
    field(:ended_at, :integer)
    field(:charge_at, :integer)
    field(:current_start, :integer)
    field(:current_end, :integer)
    field(:broker_phone_number, :string)
    field(:paytm_txn_token, :string)
    field(:is_client_side_registration_successful, :boolean, default: false)

    belongs_to(:broker, Broker)
    belongs_to(:match_plus_package, MatchPlusPackage)

    has_many(:membership_statuses, MembershipStatus, foreign_key: :membership_id)
    has_many(:membership_orders, MembershipOrder, foreign_key: :membership_id)

    timestamps()
  end

  @required [
    :match_plus_membership_id,
    :paytm_subscription_id,
    :bn_order_id,
    :created_at,
    :status,
    :broker_id,
    :bn_customer_id,
    :broker_phone_number
  ]
  @optional [
    :subscription_amount,
    :paytm_txn_token,
    :last_order_id,
    :last_order_status,
    :last_order_creation_date,
    :last_order_amount,
    :short_url,
    :payment_method,
    :start_at,
    :ended_at,
    :charge_at,
    :current_start,
    :current_end,
    :match_plus_package_id,
    :is_client_side_registration_successful
  ]

  @doc false
  def changeset(membership, attrs) do
    membership
    |> cast(attrs, @required ++ @optional)
    |> validate_required(@required)
    |> foreign_key_constraint(:broker_id)
    |> unique_constraint(:razorpay_membership_id)
  end

  def membership_status_changeset(membership, attrs) do
    status_change_fields = [
      :status,
      :current_start,
      :current_end,
      :is_client_side_registration_successful,
      :last_order_id,
      :last_order_status,
      :last_order_creation_date,
      :last_order_amount
    ]

    membership
    |> cast(attrs, status_change_fields)
    |> validate_required([:status])
    |> foreign_key_constraint(:broker_id)
  end

  def membership_billing_dates_changeset(order, attrs) do
    billing_dates_fields = [:current_start, :current_end]

    order
    |> cast(attrs, billing_dates_fields)
    |> validate_required(billing_dates_fields)
  end

  def default_txn_amount() do
    @default_txn_amount
  end

  def amount() do
    ApplicationHelper.get_paytm_subscription_amount()
  end

  def validity_in_days() do
    ApplicationHelper.get_paytm_subscription_validity_in_days()
  end

  def subscription_frequency_unit() do
    ApplicationHelper.get_paytm_subscription_frequency_unit()
  end

  def order_success() do
    @order_success
  end

  def created_status() do
    @created_status
  end

  def authenticated_status() do
    @authenticated_status
  end

  def authorization_failed_status() do
    @authorization_failed_status
  end

  def active_status() do
    @active_status
  end

  def suspended_status() do
    @suspended_status
  end

  def closed_status() do
    @closed_status
  end

  def reject_status() do
    @reject_status
  end

  def get_membership(id) do
    Repo.get_by(Membership, id: id)
  end

  def get_membership_by(attrs) do
    Repo.get_by(Membership, attrs)
  end

  def latest_membership_by_broker_by_status(broker_id, status) do
    Membership
    |> where([m], m.status == ^status)
    |> where([m], m.broker_id == ^broker_id)
    |> preload([:match_plus_package])
    |> order_by(desc: :inserted_at)
    |> limit(1)
    |> Repo.one()
  end

  def latest_paid_membership_by_broker(broker_id) do
    {amount_monthly, _} = Float.parse(Membership.amount())

    Membership
    |> where([m], m.broker_id == ^broker_id)
    |> where([m], m.last_order_status == ^Membership.order_success())
    |> where(
      [m],
      fragment("?::DECIMAL = ?::DECIMAL", m.last_order_amount, m.subscription_amount) or
        (is_nil(m.subscription_amount) and
           (fragment("?::DECIMAL = ?", m.last_order_amount, ^amount_monthly) or
              fragment("?::DECIMAL = ?", m.last_order_amount, ^@dummy_amount_monthly) or
              fragment("?::DECIMAL = ?", m.last_order_amount, ^@dummy_amount_quarterly) or
              fragment("?::DECIMAL = ?", m.last_order_amount, ^@dummy_amount_half_yearly) or
              fragment("?::DECIMAL = ?", m.last_order_amount, ^@dummy_amount_yearly)))
    )
    |> order_by(desc: :inserted_at)
    |> limit(1)
    |> Repo.one()
  end

  def active_memberships_count_by_broker(broker_id) do
    Membership
    |> where([m], m.broker_id == ^broker_id)
    |> where([m], m.status == ^Membership.active_status())
    |> where([m], m.last_order_status == ^Membership.order_success())
    |> Repo.aggregate(:count, :id)
  end

  def get_membership_end_date(membership) do
    current_start = membership.created_at

    {:ok, current_start_datetime} = DateTime.from_unix(current_start)

    current_start_datetime
    |> Timex.Timezone.convert("Asia/Kolkata")
    |> Timex.end_of_day()
    |> Timex.shift(days: Membership.validity_in_days())
    |> DateTime.to_unix()
  end

  def get_next_billing_dates(membership) do
    current_end = Membership.get_membership_end_date(membership)

    {:ok, current_end_datetime} = DateTime.from_unix(current_end)

    next_billing_start_at =
      current_end_datetime
      |> Timex.Timezone.convert("Asia/Kolkata")
      |> Timex.end_of_day()
      |> Timex.shift(days: 1)
      |> DateTime.to_unix()

    next_billing_end_at =
      current_end_datetime
      |> Timex.Timezone.convert("Asia/Kolkata")
      |> Timex.end_of_day()
      |> Timex.shift(days: 1)
      |> Timex.shift(days: 30)
      |> DateTime.to_unix()

    {next_billing_start_at, next_billing_end_at}
  end

  def create_membership!(paytm_txn_token, params, match_plus_package_id) do
    ch =
      Membership.changeset(%Membership{}, %{
        paytm_txn_token: paytm_txn_token,
        match_plus_membership_id: params[:match_plus_membership_id],
        bn_order_id: params[:bn_order_id],
        paytm_subscription_id: params[:paytm_subscription_id],
        status: params[:status],
        created_at: params[:created_at],
        bn_customer_id: params[:bn_customer_id],
        payment_method: params[:payment_method],
        last_order_id: params[:last_order_id],
        last_order_status: params[:last_order_status],
        last_order_creation_date: params[:last_order_creation_date],
        last_order_amount: params[:last_order_amount],
        subscription_amount: params[:subscription_amount],
        current_start: params[:current_start],
        current_end: params[:current_end],
        broker_phone_number: params[:broker_phone_number],
        match_plus_package_id: match_plus_package_id,
        broker_id: params[:broker_id]
      })

    membership = Repo.insert!(ch)
    MembershipStatus.create_membership_status!(membership, params)
    MembershipOrder.create_membership_order!(membership, params)

    membership
  end

  def update_membership!(%Membership{} = membership, params) do
    ch = Membership.membership_status_changeset(membership, params)
    membership = Repo.update!(ch)
    MembershipStatus.create_membership_status!(membership, params)
    MembershipOrder.create_membership_order!(membership, params)

    if membership.last_order_status == Membership.order_success() and
         (Float.parse(membership.last_order_amount) == Float.parse(Membership.amount()) or
            (!is_nil(membership.subscription_amount) and
               Float.parse(membership.last_order_amount) == Float.parse(membership.subscription_amount))) do
      verify_and_update_dates(membership)
    end

    MatchPlusMembership
    |> Repo.get_by(id: membership.match_plus_membership_id)
    |> MatchPlusMembership.verify_and_update_status()

    membership
  end

  def update_status!(%Membership{} = membership, _status, params) do
    status_params = params |> Map.take([:status])
    ch = Membership.membership_status_changeset(membership, status_params)
    membership = Repo.update!(ch)
    MembershipStatus.create_membership_status!(membership, params)

    MatchPlusMembership
    |> Repo.get_by(id: membership.match_plus_membership_id)
    |> MatchPlusMembership.verify_and_update_status()
  end

  def verify_and_update_dates(membership) do
    current_start = membership.last_order_creation_date

    {:ok, current_start_datetime} = DateTime.from_unix(current_start)

    current_end =
      current_start_datetime
      |> Timex.Timezone.convert("Asia/Kolkata")
      |> Timex.end_of_day()
      |> Timex.shift(days: Membership.validity_in_days())
      |> DateTime.to_unix()

    ch =
      Membership.membership_billing_dates_changeset(membership, %{
        current_start: current_start,
        current_end: current_end
      })

    Repo.update!(ch)
  end

  def match_plus_attributes(membership) do
    %{
      "subscription_id" => membership.id,
      "paytm_subscription_id" => membership.paytm_subscription_id,
      "is_subscription_active" => membership.status == Membership.active_status(),
      "subscription_is_client_side_payment_successful" => membership.is_client_side_registration_successful,
      "subscription_status" => membership.status,
      "subscription_created_at" => membership.inserted_at
    }
  end
end
