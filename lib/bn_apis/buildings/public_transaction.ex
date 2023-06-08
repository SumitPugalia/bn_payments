defmodule BnApis.Buildings.PublicTransaction do
  use Ecto.Schema
  import Ecto.Changeset

  alias BnApis.Buildings.Building
  alias BnApis.Posts.ConfigurationType

  schema "public_transactions" do
    field :wing, :string
    field :area, :integer
    field :price, :integer
    field :unit_number, :string
    field :transaction_type, Ecto.Enum, values: [:resale, :developer]
    field :transaction_date, :naive_datetime

    belongs_to(:configuration_type, ConfigurationType)
    belongs_to(:building, Building)

    timestamps()
  end

  @fields [
    :wing,
    :area,
    :price,
    :unit_number,
    :transaction_type,
    :transaction_date,
    :configuration_type_id,
    :building_id
  ]
  @required_fields [:price, :area, :transaction_type, :transaction_date, :configuration_type_id, :building_id]

  @doc false
  def changeset(public_transaction, attrs \\ %{}) do
    public_transaction
    |> cast(attrs, @fields)
    |> validate_required(@required_fields)
  end
end
