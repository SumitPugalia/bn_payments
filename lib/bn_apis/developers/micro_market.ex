defmodule BnApis.Developers.MicroMarket do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false
  schema "micro_markets" do
    field :id, :integer, primary_key: true
    field :name, :string

    timestamps()
  end

  @doc false
  def changeset(micro_market, params) do
    micro_market
    |> cast(params, [:id, :name])
    |> validate_required([:id, :name])
    |> unique_constraint(:name)
  end

  def changeset(params) do
    %__MODULE__{}
    |> changeset(params)
  end
end
