defmodule BnApis.Stories.SectionResourceType do
  use Ecto.Schema
  import Ecto.Changeset

  @image %{id: 1, name: "Image"}
  @video %{id: 2, name: "Video"}

  def seed_data do
    [
      @image,
      @video
    ]
  end

  @primary_key false
  schema "stories_section_resource_types" do
    field :id, :integer, primary_key: true
    field :name, :string

    timestamps()
  end

  @doc false
  def changeset(section_resource_type, params) do
    section_resource_type
    |> cast(params, [:id, :name])
    |> validate_required([:id, :name])
    |> unique_constraint(:name)
  end

  def changeset(params) do
    %__MODULE__{}
    |> changeset(params)
  end

  def image do
    @image
  end

  def video do
    @video
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
