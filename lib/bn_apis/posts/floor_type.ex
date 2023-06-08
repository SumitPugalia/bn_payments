defmodule BnApis.Posts.FloorType do
  use Ecto.Schema
  import Ecto.Changeset

  @lower %{id: 1, name: "Lower"}
  @mid %{id: 2, name: "Mid"}
  @higher %{id: 3, name: "Higher"}

  def seed_data do
    [
      @lower,
      @mid,
      @higher
    ]
  end

  @primary_key false
  schema "posts_floor_types" do
    field :id, :integer, primary_key: true
    field :name, :string

    timestamps()
  end

  @doc false
  def changeset(floor_type, params) do
    floor_type
    |> cast(params, [:id, :name])
    |> validate_required([:id, :name])
    |> unique_constraint(:name)
  end

  def changeset(params) do
    %__MODULE__{}
    |> changeset(params)
  end

  def lower do
    @lower
  end

  def mid do
    @mid
  end

  def higher do
    @higher
  end

  def get_by_id(id) when is_binary(id) do
    id = id |> String.to_integer()
    get_by_id(id)
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
