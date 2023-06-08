defmodule BnApis.Subscriptions.Subscription do
  use Ecto.Schema
  import Ecto.Changeset
  alias BnApis.Repo
  alias BnApis.Subscriptions.Subscription
  alias BnApis.Subscriptions.SubscriptionStatus
  alias BnApis.Subscriptions.SubscriptionInvoice
  alias BnApis.Subscriptions.MatchPlusSubscription

  # possible statuses: [created, authenticated, active, pending, halted, cancelled, completed, expired]
  @created_status "created"
  @authenticated_status "authenticated"
  @active_status "active"

  schema "subscriptions" do
    field(:match_plus_subscription_id, :integer)
    field(:razorpay_subscription_id, :string)
    field(:razorpay_plan_id, :string)
    field(:created_at, :integer)
    field(:razorpay_customer_id, :string)
    field(:status, :string)
    field(:short_url, :string)
    field(:payment_method, :string)
    field(:start_at, :integer)
    field(:ended_at, :integer)
    field(:charge_at, :integer)
    field(:total_count, :integer)
    field(:paid_count, :integer)
    field(:remaining_count, :integer)
    field(:current_start, :integer)
    field(:current_end, :integer)
    field(:broker_phone_number, :string)
    field(:is_client_side_registration_successful, :boolean, default: false)

    belongs_to(:broker, Broker)

    has_many(:subscription_statuses, SubscriptionStatus, foreign_key: :subscription_id)
    has_many(:subscription_invoices, SubscriptionInvoice, foreign_key: :subscription_id)

    timestamps()
  end

  @required [
    :match_plus_subscription_id,
    :razorpay_subscription_id,
    :razorpay_plan_id,
    :created_at,
    :status,
    :total_count,
    :broker_id,
    :broker_phone_number
  ]
  @optional [
    :razorpay_customer_id,
    :short_url,
    :payment_method,
    :start_at,
    :ended_at,
    :charge_at,
    :paid_count,
    :remaining_count,
    :current_start,
    :current_end,
    :is_client_side_registration_successful
  ]

  @doc false
  def changeset(subscription, attrs) do
    subscription
    |> cast(attrs, @required ++ @optional)
    |> validate_required(@required)
    |> foreign_key_constraint(:broker_id)
    |> unique_constraint(:razorpay_subscription_id)
  end

  def subscription_status_changeset(subscription, attrs) do
    status_change_fields = [
      :status,
      :charge_at,
      :paid_count,
      :remaining_count,
      :current_start,
      :current_end,
      :is_client_side_registration_successful
    ]

    subscription
    |> cast(attrs, status_change_fields)
    |> validate_required([:status])
    |> foreign_key_constraint(:broker_id)
  end

  def created_status() do
    @created_status
  end

  def authenticated_status() do
    @authenticated_status
  end

  def active_status() do
    @active_status
  end

  def get_subscription(id) do
    Repo.get_by(Subscription, id: id)
  end

  def create_subscription!(params) do
    ch =
      Subscription.changeset(%Subscription{}, %{
        match_plus_subscription_id: params[:match_plus_subscription_id],
        razorpay_plan_id: params[:razorpay_plan_id],
        razorpay_subscription_id: params[:razorpay_subscription_id],
        created_at: params[:created_at],
        razorpay_customer_id: params[:razorpay_customer_id],
        status: params[:status],
        short_url: params[:short_url],
        payment_method: params[:payment_method],
        start_at: params[:start_at],
        ended_at: params[:ended_at],
        charge_at: params[:charge_at],
        total_count: params[:total_count],
        paid_count: params[:paid_count],
        remaining_count: params[:remaining_count],
        current_start: params[:current_start],
        current_end: params[:current_end],
        broker_phone_number: params[:broker_phone_number],
        broker_id: params[:broker_id]
      })

    subscription = Repo.insert!(ch)
    SubscriptionStatus.create_subscription_status!(subscription, params)

    subscription
  end

  def update_subscription!(%Subscription{} = subscription, params) do
    ch = Subscription.subscription_status_changeset(subscription, params)
    subscription = Repo.update!(ch)
    SubscriptionStatus.create_subscription_status!(subscription, params)

    MatchPlusSubscription
    |> Repo.get_by(id: subscription.match_plus_subscription_id)
    |> MatchPlusSubscription.verify_and_update_status()

    subscription
  end

  def update_status!(%Subscription{} = subscription, _status, params) do
    status_params = params |> Map.take([:status])
    ch = Subscription.subscription_status_changeset(subscription, status_params)
    subscription = Repo.update!(ch)
    SubscriptionStatus.create_subscription_status!(subscription, params)

    MatchPlusSubscription
    |> Repo.get_by(id: subscription.match_plus_subscription_id)
    |> MatchPlusSubscription.verify_and_update_status()
  end
end
