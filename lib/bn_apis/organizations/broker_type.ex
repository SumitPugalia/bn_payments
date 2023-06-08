defmodule BnApis.Organizations.BrokerType do
  use Ecto.Schema
  import Ecto.Changeset

  @resale %{id: 1, name: "Resale"}
  @np %{id: 2, name: "NP"}
  @both %{id: 3, name: "Both"}

  def seed_data do
    [
      @resale,
      @np,
      @both
    ]
  end

  @primary_key false
  schema "brokers_types" do
    field :id, :integer, primary_key: true
    field :name, :string

    timestamps()
  end

  @doc false
  def changeset(broker_type, params) do
    broker_type
    |> cast(params, [:id, :name])
    |> validate_required([:id, :name])
    |> unique_constraint(:name)
  end

  def changeset(params) do
    %__MODULE__{}
    |> changeset(params)
  end

  def resale do
    @resale
  end

  def np do
    @np
  end

  def both do
    @both
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
