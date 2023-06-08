defmodule BnApis.Buildings.SourceType do
  use Ecto.Schema
  import Ecto.Changeset

  @sales %{id: 1, name: "Sales"}
  @internal %{id: 2, name: "Internal"}

  def seed_data do
    [
      @sales,
      @internal
    ]
  end

  @primary_key false
  schema "buildings_source_types" do
    field :id, :integer, primary_key: true
    field :name, :string

    timestamps()
  end

  @doc false
  def changeset(source_type, params) do
    source_type
    |> cast(params, [:id, :name])
    |> validate_required([:id, :name])
    |> unique_constraint(:name)
  end

  def changeset(params) do
    %__MODULE__{}
    |> changeset(params)
  end

  def sales do
    @sales
  end

  def internal do
    @internal
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
