defmodule BnApis.Packages.UserPackage do
  use Ecto.Schema
  import Ecto.Changeset

  alias BnApis.Organizations.Broker
  alias BnApis.Packages.{UserOrder, UserPackage}
  alias BnApis.Orders.MatchPlusPackage

  @derive Jason.Encoder
  @primary_key {:id, Ecto.UUID, autogenerate: true}
  schema "user_packages" do
    field(:current_start, :integer)
    field(:current_end, :integer)
    ## not sure of values yet
    field(:status, Ecto.Enum, values: [:pending, :active, :cancelled, :failed, :aborted])
    field(:type, Ecto.Enum, values: [:commercial, :owners])
    field(:auto_renew, :boolean)
    field(:mandate_mode, :string)
    field(:subscription_id, :string)
    field(:mandate_id, :string)
    field(:invoice_id, :string)

    belongs_to(:user_order, UserOrder, type: Ecto.UUID)
    belongs_to(:broker, Broker)
    belongs_to(:match_plus_package, MatchPlusPackage)

    timestamps()
  end

  @required [
    :status,
    :broker_id,
    :current_start,
    :current_end,
    :match_plus_package_id,
    :type,
    :auto_renew
  ]

  @optional [
    :mandate_mode,
    :subscription_id,
    :mandate_id,
    :invoice_id
  ]

  @doc false
  def changeset(attrs \\ %{}), do: changeset(%UserPackage{}, attrs)

  def changeset(user_package, attrs) do
    user_package
    |> cast(attrs, @required ++ @optional)
    |> cast_assoc(:user_order)
    |> validate_required(@required)
    |> foreign_key_constraint(:broker_id)
    |> foreign_key_constraint(:user_order_id)
    |> foreign_key_constraint(:match_plus_package_id)
  end

  def update_changeset(user_package, attrs) do
    user_package
    |> cast(attrs, @required ++ @optional)
    |> foreign_key_constraint(:broker_id)
    |> foreign_key_constraint(:user_order_id)
    |> foreign_key_constraint(:match_plus_package_id)
  end

  def active_status(), do: :active
  def pending_status(), do: :pending
  def cancelled_status(), do: :cancelled
  def failed_status(), do: :failed
end
