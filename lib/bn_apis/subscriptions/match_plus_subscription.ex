defmodule BnApis.Subscriptions.MatchPlusSubscription do
  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query, warn: false
  alias BnApis.Repo
  alias BnApis.Organizations.Broker
  alias BnApis.Accounts.Credential
  alias BnApis.Subscriptions.Subscription
  alias BnApis.Subscriptions.MatchPlusSubscription

  @active_status_id 1
  @inactive_status_id 2

  schema "match_plus_subscriptions" do
    field :status_id, :integer
    belongs_to(:broker, Broker)

    belongs_to(:latest_subscription, Subscription,
      foreign_key: :latest_subscription_id,
      references: :id
    )

    has_many(:subscriptions, Subscription, foreign_key: :match_plus_subscription_id)

    timestamps()
  end

  @required [:broker_id, :status_id]
  @optional [:latest_subscription_id]

  @doc false
  def changeset(match_plus_subscription, attrs) do
    match_plus_subscription
    |> cast(attrs, @required ++ @optional)
    |> validate_required(@required)
    |> foreign_key_constraint(:broker_id)
    |> foreign_key_constraint(:latest_subscription_id)
  end

  def latest_subscription_changeset(match_plus_subscription, attrs) do
    match_plus_subscription
    |> cast(attrs, [:latest_subscription_id])
    |> validate_required([:latest_subscription_id])
    |> foreign_key_constraint(:broker_id)
    |> foreign_key_constraint(:latest_subscription_id)
  end

  def status_changeset(match_plus_subscription, attrs) do
    match_plus_subscription
    |> cast(attrs, [:status_id])
    |> validate_required([:status_id])
    |> foreign_key_constraint(:broker_id)
    |> foreign_key_constraint(:latest_subscription_id)
  end

  def active_status_id() do
    @active_status_id
  end

  def inactive_status_id() do
    @inactive_status_id
  end

  def find_or_create!(broker_id) do
    match_plus_subscription = Repo.get_by(MatchPlusSubscription, broker_id: broker_id)

    if not is_nil(match_plus_subscription) do
      match_plus_subscription
    else
      MatchPlusSubscription.create!(broker_id)
    end
  end

  def create!(broker_id) do
    status_id = 2

    ch =
      MatchPlusSubscription.changeset(%MatchPlusSubscription{}, %{
        broker_id: broker_id,
        status_id: status_id
      })

    Repo.insert!(ch)
  end

  def get_data(nil) do
    %{}
  end

  def get_data(match_plus_subscription) do
    match_plus_subscription = match_plus_subscription |> Repo.preload([:latest_subscription])
    subscription = match_plus_subscription.latest_subscription

    if is_nil(subscription) do
      %{
        "is_match_plus_active" => match_plus_subscription.status_id == 1,
        "is_subscription_active" => false,
        "razorpay_subscription_id" => nil,
        "subscription_billing_start_at" => nil,
        "subscription_billing_end_at" => nil,
        "subscription_next_billing_charge_at" => nil,
        "subscription_id" => nil,
        "subscription_is_client_side_registration_successful" => false,
        "subscription_status" => nil
      }
    else
      %{
        "is_match_plus_active" => match_plus_subscription.status_id == 1,
        "is_subscription_active" => subscription.status == "active",
        "razorpay_subscription_id" => subscription.razorpay_subscription_id,
        "subscription_billing_start_at" => subscription.current_start,
        "subscription_billing_end_at" => subscription.current_end,
        "subscription_next_billing_charge_at" => subscription.charge_at,
        "subscription_id" => subscription.id,
        "subscription_is_client_side_registration_successful" => subscription.is_client_side_registration_successful,
        "subscription_status" => subscription.status
      }
    end
  end

  def get_data_by_broker(broker) do
    Repo.get_by(MatchPlusSubscription, broker_id: broker.id)
    |> MatchPlusSubscription.get_data()
  end

  def update_latest_subscription!(%MatchPlusSubscription{} = match_plus_subscription, latest_subscription_id) do
    ch =
      MatchPlusSubscription.latest_subscription_changeset(match_plus_subscription, %{
        latest_subscription_id: latest_subscription_id
      })

    Repo.update!(ch)
  end

  def update_status!(%MatchPlusSubscription{} = match_plus_subscription, status_id) do
    ch =
      MatchPlusSubscription.status_changeset(match_plus_subscription, %{
        status_id: status_id
      })

    Repo.update!(ch)
  end

  def verify_and_update_status(match_plus_subscription) do
    match_plus_subscription = match_plus_subscription |> Repo.preload(:latest_subscription)
    subscription = match_plus_subscription.latest_subscription

    status_id =
      if subscription.status == Subscription.active_status() do
        @active_status_id
      else
        current_timestamp = DateTime.utc_now() |> DateTime.to_unix()

        if !is_nil(subscription.current_start) and
             !is_nil(subscription.current_end) and
             subscription.current_start <= current_timestamp and
             current_timestamp <= subscription.current_end do
          @active_status_id
        else
          @inactive_status_id
        end
      end

    MatchPlusSubscription.update_status!(match_plus_subscription, status_id)
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
      MatchPlusSubscription
      |> join(:inner, [mps], s in Subscription, on: mps.latest_subscription_id == s.id)
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
      if not is_nil(params["subscription_status"]) do
        query |> where([mps, s, cred, bro], s.status == ^params["subscription_status"])
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

  def fetch_subscriptions(params) do
    {query, content_query, page, size} = MatchPlusSubscription.filter_query(params)

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
        is_subscription_active:
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
        subscription_status: s.status,
        razorpay_subscription_id: s.razorpay_subscription_id,
        subscription_next_billing_charge_at: s.charge_at,
        subscription_is_client_side_registration_successful: s.is_client_side_registration_successful,
        subscription_billing_start_at: s.current_start,
        subscription_billing_end_at: s.current_end,
        subscription_created_at: s.inserted_at
      })
      |> Repo.all()

    total_count =
      query
      |> Repo.aggregate(:count, :id)

    has_more_subscriptions = page < Float.ceil(total_count / size)
    {posts, total_count, has_more_subscriptions}
  end
end
