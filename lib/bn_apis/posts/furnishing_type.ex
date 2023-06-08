defmodule BnApis.Posts.FurnishingType do
  use Ecto.Schema
  import Ecto.Changeset

  @unfurnished %{id: 1, name: "Unfurnished"}
  @semi_furnished %{id: 2, name: "Semi-Furnished"}
  @fully_furnished %{id: 3, name: "Fully-Furnished"}

  def seed_data do
    [
      @unfurnished,
      @semi_furnished,
      @fully_furnished
    ]
  end

  @one_two %{id: "1-2", name: "Semi / Unfurnished"}
  @one_three %{id: "1-3", name: "Fully / Unfurnished"}
  @two_three %{id: "2-3", name: "Fully / Semi-Furnished"}
  @one_two_three %{id: "1-2-3", name: "Any Furnishing"}
  defp combined_name_mapping do
    [
      @one_two,
      @one_three,
      @two_three,
      @one_two_three
    ]
  end

  @primary_key false
  schema "posts_furnishing_types" do
    field :id, :integer, primary_key: true
    field :name, :string

    timestamps()
  end

  @doc false
  def changeset(furnishing_type, params) do
    furnishing_type
    |> cast(params, [:id, :name])
    |> validate_required([:id, :name])
    |> unique_constraint(:name)
  end

  def changeset(params) do
    %__MODULE__{}
    |> changeset(params)
  end

  def unfurnished do
    @unfurnished
  end

  def semi_furnished do
    @semi_furnished
  end

  def fully_furnished do
    @fully_furnished
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

  def get_combined_name(ids) do
    data =
      if ids |> String.split("-") |> length != 1 do
        combined_name_mapping()
      else
        seed_data()
      end

    data
    |> Enum.filter(&(&1.id |> to_string == ids))
    |> List.first()
    |> return_name
  end

  defp return_name(nil), do: nil
  defp return_name(map), do: map |> Map.get(:name)
end
