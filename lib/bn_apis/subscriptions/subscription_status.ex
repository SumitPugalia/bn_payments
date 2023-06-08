defmodule BnApis.Subscriptions.SubscriptionStatus do
  use Ecto.Schema
  import Ecto.Changeset
  alias BnApis.Repo
  alias BnApis.Subscriptions.Subscription
  alias BnApis.Subscriptions.SubscriptionStatus

  schema "subscription_status" do
    field(:status, :string)
    field(:razorpay_data, :map)
    field(:created_at, :integer)
    field(:razorpay_customer_id, :string)
    field(:razorpay_event_id, :string)
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

    belongs_to(:subscription, Subscription)

    timestamps()
  end

  @required [:status, :subscription_id]
  @optional [
    :razorpay_data,
    :created_at,
    :razorpay_customer_id,
    :razorpay_event_id,
    :short_url,
    :payment_method,
    :start_at,
    :ended_at,
    :charge_at,
    :total_count,
    :paid_count,
    :remaining_count,
    :current_start,
    :current_end
  ]

  @doc false
  def changeset(subscription_status, attrs) do
    subscription_status
    |> cast(attrs, @required ++ @optional)
    |> validate_required(@required)
    |> foreign_key_constraint(:subscription_id)
  end

  def create_subscription_status!(
        subscription,
        params
      ) do
    changeset =
      SubscriptionStatus.changeset(%SubscriptionStatus{}, %{
        subscription_id: subscription.id,
        status: params[:status],
        razorpay_data: params[:razorpay_data],
        created_at: params[:created_at],
        razorpay_customer_id: params[:razorpay_customer_id],
        razorpay_event_id: params[:razorpay_event_id],
        short_url: params[:short_url],
        payment_method: params[:payment_method],
        start_at: params[:start_at],
        ended_at: params[:ended_at],
        charge_at: params[:charge_at],
        total_count: params[:total_count],
        paid_count: params[:paid_count],
        remaining_count: params[:remaining_count],
        current_start: params[:current_start],
        current_end: params[:current_end]
      })

    Repo.insert!(changeset)
  end
end
