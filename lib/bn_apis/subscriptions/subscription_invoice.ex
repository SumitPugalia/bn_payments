defmodule BnApis.Subscriptions.SubscriptionInvoice do
  use Ecto.Schema
  import Ecto.Changeset
  alias BnApis.Repo
  alias BnApis.Subscriptions.Subscription
  alias BnApis.Subscriptions.SubscriptionInvoice

  schema "subscription_invoices" do
    field(:razorpay_invoice_id, :string)
    field(:razorpay_invoice_status, :string)
    field(:razorpay_order_id, :string)
    field(:razorpay_payment_id, :string)
    field(:razorpay_data, :map)
    field(:created_at, :integer)
    field(:razorpay_customer_id, :string)
    field(:short_url, :string)
    field(:invoice_number, :string)
    field(:billing_start, :integer)
    field(:billing_end, :integer)
    field(:paid_at, :integer)
    field(:amount, :integer)
    field(:amount_paid, :integer)
    field(:amount_due, :integer)
    field(:date, :integer)
    field(:partial_payment, :boolean)
    field(:tax_amount, :integer)
    field(:taxable_amount, :integer)
    field(:currency, :string)
    belongs_to(:subscription, Subscription)

    timestamps()
  end

  @required [:razorpay_invoice_id, :razorpay_invoice_status, :subscription_id]
  @optional [
    :razorpay_order_id,
    :razorpay_payment_id,
    :razorpay_data,
    :created_at,
    :razorpay_customer_id,
    :short_url,
    :invoice_number,
    :billing_start,
    :billing_end,
    :paid_at,
    :amount,
    :amount_paid,
    :amount_due,
    :date,
    :partial_payment,
    :tax_amount,
    :taxable_amount,
    :currency
  ]

  @doc false
  def changeset(subscription_invoice, attrs) do
    subscription_invoice
    |> cast(attrs, @required ++ @optional)
    |> validate_required(@required)
    |> foreign_key_constraint(:subscription_id)
    |> unique_constraint(:razorpay_invoice_id)
  end

  def fetch_by_invoice_id(razorpay_invoice_id) do
    SubscriptionInvoice |> Repo.get_by(razorpay_invoice_id: razorpay_invoice_id)
  end

  def create_subscription_invoice!(
        subscription,
        params
      ) do
    changeset =
      SubscriptionInvoice.changeset(%SubscriptionInvoice{}, %{
        subscription_id: subscription.id,
        razorpay_invoice_id: params[:razorpay_invoice_id],
        razorpay_invoice_status: params[:razorpay_invoice_status],
        razorpay_order_id: params[:razorpay_order_id],
        razorpay_payment_id: params[:razorpay_payment_id],
        razorpay_data: params[:razorpay_data],
        created_at: params[:created_at],
        razorpay_customer_id: params[:razorpay_customer_id],
        short_url: params[:short_url],
        invoice_number: params[:invoice_number],
        billing_start: params[:billing_start],
        billing_end: params[:billing_end],
        paid_at: params[:paid_at],
        amount: params[:amount],
        amount_paid: params[:amount_paid],
        amount_due: params[:amount_due],
        date: params[:date],
        partial_payment: params[:partial_payment],
        tax_amount: params[:tax_amount],
        taxable_amount: params[:taxable_amount],
        currency: params[:currency]
      })

    Repo.insert!(changeset)
  end
end
