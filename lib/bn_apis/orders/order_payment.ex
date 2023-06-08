defmodule BnApis.Orders.OrderPayment do
  use Ecto.Schema
  import Ecto.Changeset
  alias BnApis.Repo
  alias BnApis.Orders.Order
  alias BnApis.Orders.OrderPayment

  # possible statuses: [created, authorized, captured, refunded, failed]
  @captured_status "captured"
  @authorized_status "authorized"

  schema "order_payments" do
    field(:razorpay_order_id, :string)
    field(:razorpay_payment_id, :string)
    field(:razorpay_payment_status, :string)
    field(:amount, :integer)
    field(:currency, :string)
    field(:created_at, :integer)
    field(:razorpay_data, :map)
    field(:invoice_id, :string)
    field(:international, :boolean)
    field(:method, :string)
    field(:amount_refunded, :integer)
    field(:refund_status, :string)
    field(:captured, :boolean)
    field(:description, :string)
    field(:card_id, :string)
    field(:bank, :string)
    field(:wallet, :string)
    field(:vpa, :string)
    field(:tax, :integer)
    field(:fee, :integer)
    field(:email, :string)
    field(:contact, :string)
    field(:notes, {:array, :string})
    field(:error_code, :string)
    field(:error_description, :string)
    field(:error_source, :string)
    field(:error_step, :string)
    field(:error_reason, :string)

    belongs_to(:order, Order)

    timestamps()
  end

  @required [:razorpay_order_id, :razorpay_payment_id, :razorpay_payment_status, :amount, :order_id]
  @optional [
    :currency,
    :created_at,
    :razorpay_data,
    :invoice_id,
    :international,
    :method,
    :amount_refunded,
    :refund_status,
    :captured,
    :description,
    :card_id,
    :bank,
    :wallet,
    :vpa,
    :tax,
    :fee,
    :email,
    :contact,
    :notes,
    :error_code,
    :error_description,
    :error_source,
    :error_step,
    :error_reason
  ]

  @doc false
  def changeset(order_payment, attrs) do
    order_payment
    |> cast(attrs, @required ++ @optional)
    |> validate_required(@required)
    |> foreign_key_constraint(:order_id)
    |> unique_constraint(:razorpay_payment_id)
  end

  def captured_status() do
    @captured_status
  end

  def authorized_status() do
    @authorized_status
  end

  def fetch_by_payment_id(razorpay_payment_id) do
    OrderPayment |> Repo.get_by(razorpay_payment_id: razorpay_payment_id)
  end

  def create_order_payment!(
        order,
        params
      ) do
    changeset =
      OrderPayment.changeset(%OrderPayment{}, %{
        order_id: order.id,
        razorpay_order_id: params[:razorpay_order_id],
        razorpay_payment_id: params[:razorpay_payment_id],
        razorpay_payment_status: params[:razorpay_payment_status],
        amount: params[:amount],
        currency: params[:currency],
        created_at: params[:created_at],
        razorpay_data: params[:razorpay_data],
        invoice_id: params[:invoice_id],
        international: params[:international],
        method: params[:method],
        amount_refunded: params[:amount_refunded],
        refund_status: params[:refund_status],
        captured: params[:captured],
        description: params[:description],
        card_id: params[:card_id],
        bank: params[:bank],
        wallet: params[:wallet],
        vpa: params[:vpa],
        tax: params[:tax],
        fee: params[:fee],
        email: params[:email],
        contact: params[:contact],
        notes: params[:notes],
        error_code: params[:error_code],
        error_description: params[:error_description],
        error_source: params[:error_source],
        error_step: params[:error_step],
        error_reason: params[:error_reason]
      })

    Repo.insert!(changeset)
  end

  def update_order_payment!(
        order_payment,
        params
      ) do
    changeset =
      OrderPayment.changeset(order_payment, %{
        razorpay_payment_status: params[:razorpay_payment_status],
        amount: params[:amount],
        currency: params[:currency],
        created_at: params[:created_at],
        razorpay_data: params[:razorpay_data],
        invoice_id: params[:invoice_id],
        international: params[:international],
        method: params[:method],
        amount_refunded: params[:amount_refunded],
        refund_status: params[:refund_status],
        captured: params[:captured],
        description: params[:description],
        card_id: params[:card_id],
        bank: params[:bank],
        wallet: params[:wallet],
        vpa: params[:vpa],
        tax: params[:tax],
        fee: params[:fee],
        email: params[:email],
        contact: params[:contact],
        notes: params[:notes],
        error_code: params[:error_code],
        error_description: params[:error_description],
        error_source: params[:error_source],
        error_step: params[:error_step],
        error_reason: params[:error_reason]
      })

    Repo.update!(changeset)
  end
end
