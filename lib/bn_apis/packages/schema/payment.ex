defmodule BnApis.Packages.Payment do
  use Ecto.Schema
  import Ecto.Changeset
  alias BnApis.Packages.{UserOrder, Invoice}

  @derive Jason.Encoder
  schema "payments" do
    field(:payment_id, :string)
    field(:payment_status, Ecto.Enum, values: [:captured, :pending, :failed])
    field(:amount, :integer)
    field(:currency, :string)
    field(:created_at, :integer)
    field(:payment_data, :map)
    field(:payment_gateway, Ecto.Enum, values: [:paytm, :razorpay, :billdesk])
    field(:international, :boolean)
    field(:method, :string)
    field(:amount_refunded, :integer)
    field(:refund_status, :string)
    field(:captured, :boolean)
    field(:description, :string)
    field(:payment_method_type, :string)
    field(:tax, :integer)
    field(:fee, :integer)
    field(:email, :string)
    field(:contact, :string)
    field(:notes, :string)

    belongs_to(:user_order, UserOrder, type: Ecto.UUID)
    has_one(:invoice, Invoice)
    timestamps()
  end

  @required [:currency, :created_at, :payment_data, :payment_id, :payment_status, :amount, :payment_gateway]
  @optional [
    :international,
    :method,
    :amount_refunded,
    :refund_status,
    :captured,
    :description,
    :payment_method_type,
    :tax,
    :fee,
    :email,
    :contact,
    :notes,
    :user_order_id
  ]

  @doc false
  def changeset(order_payment, attrs) do
    order_payment
    |> cast(attrs, @required ++ @optional)
    |> cast_assoc(:user_order)
    |> validate_required(@required)
    |> unique_constraint(:payment_id)
    |> foreign_key_constraint(:user_order_id)
  end

  def captured_status(), do: :captured
  def pending_status(), do: :pending
  def failed_status(), do: :failed
end
