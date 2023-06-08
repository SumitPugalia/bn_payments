defmodule BnApis.Orders.OrderStatus do
  use Ecto.Schema
  import Ecto.Changeset
  alias BnApis.Repo
  alias BnApis.Orders.Order
  alias BnApis.Orders.OrderStatus

  schema "order_status" do
    field(:razorpay_order_id, :string)
    field(:amount, :integer)
    field(:amount_paid, :integer)
    field(:amount_due, :integer)
    field(:currency, :string)
    field(:receipt, :string)
    field(:attempts, :integer)
    field(:status, :string)
    field(:razorpay_data, :map)
    field(:created_at, :integer)
    field(:razorpay_event_id, :string)

    belongs_to(:order, Order)

    timestamps()
  end

  @required [:status, :order_id]
  @optional [
    :razorpay_order_id,
    :razorpay_data,
    :created_at,
    :razorpay_event_id,
    :amount,
    :amount_paid,
    :amount_due,
    :currency,
    :receipt,
    :attempts
  ]

  @doc false
  def changeset(order_status, attrs) do
    order_status
    |> cast(attrs, @required ++ @optional)
    |> validate_required(@required)
    |> foreign_key_constraint(:order_id)
  end

  def create_order_status!(
        order,
        params
      ) do
    changeset =
      OrderStatus.changeset(%OrderStatus{}, %{
        order_id: order.id,
        status: params[:status],
        razorpay_data: params[:razorpay_data],
        created_at: params[:created_at],
        razorpay_event_id: params[:razorpay_event_id],
        razorpay_order_id: params[:razorpay_order_id],
        amount: params[:amount],
        amount_paid: params[:amount_paid],
        amount_due: params[:amount_due],
        currency: params[:currency],
        receipt: params[:receipt],
        attempts: params[:attempts]
      })

    Repo.insert!(changeset)
  end
end
