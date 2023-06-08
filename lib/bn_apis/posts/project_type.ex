defmodule BnApis.Posts.ProjectType do
  use Ecto.Schema
  import Ecto.Changeset

  @under_construction %{id: 1, name: "Under construction"}
  @ready_to_move %{id: 2, name: "Ready to move"}

  def seed_data do
    [
      @under_construction,
      @ready_to_move
    ]
  end

  @primary_key false
  schema "posts_project_types" do
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

  def under_construction do
    @under_construction
  end

  def ready_to_move do
    @ready_to_move
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
