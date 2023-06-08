defmodule BnApis.Transactions.Status do
  use Ecto.Schema
  import Ecto.Changeset

  @unprocessed %{id: 1, name: "Unprocessed"}
  @in_process %{id: 2, name: "In Process"}
  @processed %{id: 3, name: "Processed"}
  @invalid %{id: 4, name: "Invalid"}

  @primary_key false
  schema "transactions_statuses" do
    field :id, :integer, primary_key: true
    field :name, :string

    timestamps()
  end

  def seed_data do
    [
      @unprocessed,
      @in_process,
      @processed,
      @invalid
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

  def unprocessed do
    @unprocessed
  end

  def processed do
    @processed
  end

  def in_process do
    @in_process
  end

  def invalid do
    @invalid
  end

  def get_by_id(id) do
    seed_data()
    |> Enum.filter(&(&1.id == id))
    |> List.first()
  end

  def get_by_name(name) do
    seed_data()
    |> Enum.filter(&(&1.name == name))
    |> List.first()
  end
end
