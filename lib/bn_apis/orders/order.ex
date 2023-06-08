defmodule BnApis.Orders.Order do
  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query

  alias BnApis.Repo
  alias BnApis.Organizations.Broker
  alias BnApis.Orders
  alias BnApis.Orders.Order
  alias BnApis.Orders.OrderStatus
  alias BnApis.Orders.OrderPayment
  alias BnApis.Orders.MatchPlus
  alias BnApis.Orders.MatchPlusPackage

  # possible statuses: [created, attempted, paid]
  @created_status "created"
  @attempted_status "attempted"
  @paid_status "paid"

  schema "orders" do
    field(:razorpay_order_id, :string)
    field(:amount, :integer)
    field(:amount_paid, :integer)
    field(:amount_due, :integer)
    field(:created_at, :integer)
    field(:currency, :string)
    field(:receipt, :string)
    field(:status, :string)
    field(:attempts, :integer)
    field(:invoice_url, :string)

    field(:current_start, :integer)
    field(:current_end, :integer)
    field(:broker_phone_number, :string)
    field(:is_client_side_payment_successful, :boolean, default: false)
    field(:is_captured, :boolean, default: false)

    field(:gst, :string)
    field(:gst_legal_name, :string)
    field(:gst_pan, :string)
    field(:gst_constitution, :string)
    field(:gst_address, :string)
    field(:is_gst_invoice, :boolean)
    field(:notes, :string)

    belongs_to(:broker, Broker)
    belongs_to(:match_plus, MatchPlus)
    belongs_to(:match_plus_package, MatchPlusPackage)

    has_many(:order_statuses, OrderStatus, foreign_key: :order_id)
    has_many(:order_payments, OrderPayment, foreign_key: :order_id)

    timestamps()
  end

  @required [
    :match_plus_id,
    :razorpay_order_id,
    :amount,
    :created_at,
    :currency,
    :status,
    :broker_id,
    :broker_phone_number
  ]
  @optional [
    :receipt,
    :invoice_url,
    :attempts,
    :amount_paid,
    :amount_due,
    :current_start,
    :current_end,
    :is_client_side_payment_successful,
    :is_captured,
    :gst,
    :gst_legal_name,
    :gst_pan,
    :gst_constitution,
    :gst_address,
    :is_gst_invoice,
    :match_plus_package_id,
    :notes
  ]

  @doc false
  def changeset(order, attrs) do
    order
    |> cast(attrs, @required ++ @optional)
    |> validate_required(@required)
    |> foreign_key_constraint(:broker_id)
    |> unique_constraint(:razorpay_order_id)
  end

  def order_status_changeset(order, attrs) do
    status_change_fields = [
      :status,
      :amount,
      :amount_paid,
      :amount_due,
      :receipt,
      :attempts,
      :is_client_side_payment_successful
    ]

    order
    |> cast(attrs, status_change_fields)
    |> validate_required([:status])
    |> foreign_key_constraint(:broker_id)
  end

  def order_billing_dates_changeset(order, attrs) do
    billing_dates_fields = [:current_start, :current_end]

    order
    |> cast(attrs, billing_dates_fields)
    |> validate_required(billing_dates_fields)
  end

  def order_gst_changeset(order, attrs) do
    gst_change_fields = [:gst, :gst_legal_name, :gst_pan, :gst_constitution, :gst_address]

    order
    |> cast(attrs, gst_change_fields)
    |> validate_required(gst_change_fields)
  end

  def created_status() do
    @created_status
  end

  def attempted_status() do
    @attempted_status
  end

  def paid_status() do
    @paid_status
  end

  def get_order(id) do
    Repo.get_by(Order, id: id)
  end

  def get_order_by(attrs) do
    Repo.get_by(Order, attrs)
  end

  def get_captured_payment(order) do
    order = order |> Repo.preload(:order_payments)

    order.order_payments
    |> Enum.filter(
      &(&1.razorpay_payment_status == OrderPayment.captured_status() or
          &1.razorpay_payment_status == OrderPayment.authorized_status())
    )
    |> List.first()
  end

  def get_latest_paid_order_of_a_broker(broker_id) do
    Order
    |> where([o], o.broker_id == ^broker_id and o.status == ^@paid_status)
    |> order_by([o], desc: o.inserted_at)
    |> limit(1)
    |> Repo.one()
  end

  def get_previous_paid_order_of_a_broker(broker_id, current_order_payment_date) do
    Order
    |> join(:inner, [o], op in OrderPayment, on: op.order_id == o.id)
    |> where([o, op], o.broker_id == ^broker_id and o.status == ^@paid_status)
    |> where([o, op], op.razorpay_payment_status == ^OrderPayment.captured_status())
    |> where([o, op], op.created_at < ^current_order_payment_date)
    |> order_by([o, op], desc: op.created_at)
    |> limit(1)
    |> Repo.one()
  end

  def create_order!(params, match_plus_package_id) do
    ch =
      Order.changeset(%Order{}, %{
        match_plus_id: params[:match_plus_id],
        razorpay_order_id: params[:razorpay_order_id],
        created_at: params[:created_at],
        status: params[:status],
        amount: params[:amount],
        amount_due: params[:amount_due],
        amount_paid: params[:amount_paid],
        currency: params[:currency],
        broker_phone_number: params[:broker_phone_number],
        match_plus_package_id: match_plus_package_id,
        broker_id: params[:broker_id]
      })

    order = Repo.insert!(ch)
    OrderStatus.create_order_status!(order, params)

    order
  end

  def update_order!(%Order{} = order, params) do
    ch = Order.order_status_changeset(order, params)
    order = Repo.update!(ch)
    OrderStatus.create_order_status!(order, params)

    Orders.update_order_payments(order)
    captured_payment = Order.get_captured_payment(order)

    if not is_nil(captured_payment) do
      if order.is_client_side_payment_successful and
           captured_payment.razorpay_payment_status == OrderPayment.authorized_status() do
        Orders.update_order_payment_as_captured(captured_payment)
      end

      verify_and_update_dates(captured_payment, order)
      Order.changeset(order, %{is_captured: true}) |> Repo.update!()
      update_invoice(order)
    end

    MatchPlus
    |> Repo.get_by(id: order.match_plus_id)
    |> MatchPlus.verify_and_update_status()

    order
  end

  def update_gst!(%Order{} = order, params) do
    ch = Order.order_gst_changeset(order, params)
    order = Repo.update!(ch)
    update_invoice(order, true)
    order
  end

  def update_invoice(order, notify_broker \\ false) do
    Exq.enqueue(Exq, "invoices", BnApis.Orders.OrderInvoiceWorker, [order.id, notify_broker])
  end

  def update_status!(%Order{} = order, _status, params) do
    status_params = params |> Map.take([:status])
    ch = Order.order_status_changeset(order, status_params)
    order = Repo.update!(ch)
    OrderStatus.create_order_status!(order, params)
  end

  def verify_and_update_dates(captured_payment, order) do
    previous_paid_order = Order.get_previous_paid_order_of_a_broker(order.broker_id, captured_payment.created_at)

    current_start =
      if is_nil(previous_paid_order) do
        captured_payment.created_at
      else
        current_timestamp = DateTime.utc_now() |> DateTime.to_unix()

        if current_timestamp > previous_paid_order.current_end do
          captured_payment.created_at
        else
          {:ok, previous_paid_order_current_end_datetime} = DateTime.from_unix(previous_paid_order.current_end)

          previous_paid_order_current_end_datetime
          |> Timex.Timezone.convert("Asia/Kolkata")
          |> Timex.shift(days: 1)
          |> Timex.beginning_of_day()
          |> DateTime.to_unix()
        end
      end

    order = order |> Repo.preload(:match_plus_package)

    validity_in_days =
      if is_nil(order.match_plus_package),
        do: 30,
        else: order.match_plus_package.validity_in_days

    {:ok, current_start_datetime} = DateTime.from_unix(current_start)

    current_end =
      current_start_datetime
      |> Timex.Timezone.convert("Asia/Kolkata")
      |> Timex.end_of_day()
      |> Timex.shift(days: validity_in_days)
      |> DateTime.to_unix()

    ch =
      Order.order_billing_dates_changeset(order, %{
        current_start: current_start,
        current_end: current_end
      })

    Repo.update!(ch)
  end

  def next_billing_start_at(order) do
    if is_nil(order.current_end) do
      nil
    else
      {:ok, datetime} = DateTime.from_unix(order.current_end)

      datetime
      |> Timex.Timezone.convert("Asia/Kolkata")
      |> Timex.shift(days: 1)
      |> Timex.beginning_of_day()
      |> DateTime.to_unix()
    end
  end

  def next_billing_end_at(next_billing_start_at) do
    if is_nil(next_billing_start_at) do
      nil
    else
      {:ok, next_billing_start_at_datetime} = DateTime.from_unix(next_billing_start_at)

      next_billing_start_at_datetime
      |> Timex.Timezone.convert("Asia/Kolkata")
      |> Timex.shift(days: 1)
      |> Timex.end_of_day()
      |> Timex.shift(days: 30)
      |> DateTime.to_unix()
    end
  end

  def get_orders_by_phone_number(broker_phone_number) do
    Order
    |> where([o], o.broker_phone_number == ^broker_phone_number and o.status == ^@paid_status)
    |> join(:inner, [o], op in OrderPayment, on: op.order_id == o.id)
    |> where([o, op], op.razorpay_payment_status == ^OrderPayment.captured_status())
    |> order_by(desc: :updated_at)
    |> select([o, op], %{
      order_id: o.id,
      order_status: o.status,
      order_amount: o.amount,
      order_creation_date: op.created_at,
      currency: o.currency
    })
    |> Repo.all()
  end
end
