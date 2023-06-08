defmodule BnApis.Transactions.District do
  use Ecto.Schema
  import Ecto.Changeset

  schema "transactions_districts" do
    field :uuid, Ecto.UUID, read_after_writes: true
    field :address, :string
    field :name, :string

    timestamps()
  end

  @doc false
  def changeset(district, attrs) do
    district
    |> cast(attrs, [:name, :address])
    |> validate_required([:name])
  end

  def changeset(attrs) do
    %__MODULE__{}
    |> changeset(attrs)
  end
end
