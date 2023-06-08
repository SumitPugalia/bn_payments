defmodule BnApis.Transactions.DocType do
  use Ecto.Schema
  import Ecto.Changeset

  @rent %{id: 1, name: "Rent"}
  @sale %{id: 2, name: "Sale"}

  @primary_key false
  schema "transactions_doctypes" do
    field :id, :integer, primary_key: true
    field :name, :string

    timestamps()
  end

  def seed_data do
    [
      @rent,
      @sale
    ]
  end

  def changeset(status, params) do
    status
    |> cast(params, [:id, :name])
    |> validate_required([:id, :name])
    |> unique_constraint(:name)
  end

  def changeset(params) do
    %__MODULE__{}
    |> changeset(params)
  end

  def rent do
    @rent
  end

  def sale do
    @sale
  end
end
