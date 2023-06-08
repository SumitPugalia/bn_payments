defmodule BnApis.Packages.UserOrder do
  use Ecto.Schema
  import Ecto.Changeset

  alias BnApis.Organizations.Broker
  alias BnApis.Packages.{UserPackage, Payment}

  @derive Jason.Encoder
  @primary_key {:id, Ecto.UUID, autogenerate: true}
  schema "user_orders" do
    field(:amount, :integer)
    field(:amount_paid, :integer)
    field(:amount_due, :integer)
    field(:created_at, :integer)
    field(:currency, Ecto.Enum, values: [:inr])
    field(:is_client_side_payment_successful, :boolean, default: false)
    field(:is_captured, :boolean, default: false)
    field(:status, Ecto.Enum, values: [:created, :paid, :failed, :aborted])
    field(:notes, :string)

    field(:pg_order_id, :string)
    field(:pg_request, :map)
    field(:pg_response, :map)

    belongs_to(:broker, Broker)
    has_many(:user_packages, UserPackage, foreign_key: :user_order_id)
    has_many(:payments, Payment, foreign_key: :user_order_id)
    timestamps()
  end

  @required [
    :amount,
    :amount_paid,
    :amount_due,
    :created_at,
    :currency,
    :status,
    :broker_id
  ]

  @optional [
    :is_client_side_payment_successful,
    :is_captured,
    :notes,
    :pg_request,
    :pg_response,
    :pg_order_id
  ]

  @doc false
  def changeset(order, attrs) do
    order
    |> cast(attrs, @required ++ @optional)
    |> cast_assoc(:user_packages,
      with: &UserPackage.changeset/2,
      required: true
    )
    |> validate_required(@required)
    |> foreign_key_constraint(:broker_id)
  end

  def update_changeset(order, attrs) do
    order
    |> cast(attrs, [:status, :amount_paid, :amount_due] ++ @optional)
    |> cast_assoc(:payments,
      with: &Payment.changeset/2
    )
    |> cast_assoc(:user_packages,
      with: &UserPackage.update_changeset/2
    )
    |> foreign_key_constraint(:broker_id)
  end

  def created_status(), do: :created
  def paid_status(), do: :paid
  def failed_status(), do: :failed
end
