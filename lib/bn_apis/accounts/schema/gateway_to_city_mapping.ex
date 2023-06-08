defmodule BnApis.Accounts.Schema.GatewayToCityMapping do
  use Ecto.Schema
  import Ecto.Changeset

  alias BnApis.Places.City

  @fields ~w(city_ids active name)a

  @primary_key {:id, :binary_id, autogenerate: true}
  schema "gateway_to_city_mapping" do
    field :city_ids, {:array, :integer}, default: []
    field :active, :boolean
    field :name, :string
    timestamps()
  end

  def seed_data do
    [%{name: razorpay(), active: true, city_ids: Enum.map(City.seed_data(), & &1[:id])}]
  end

  def changeset(struct, params) do
    struct
    |> cast(params, @fields)
    |> validate_required(@fields)
  end

  def denarri, do: "denarri"
  def razorpay, do: "razorpay"
end
