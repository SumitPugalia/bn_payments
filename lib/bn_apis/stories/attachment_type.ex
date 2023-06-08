defmodule BnApis.Stories.AttachmentType do
  use Ecto.Schema
  import Ecto.Changeset

  @image %{id: 1, name: "Image"}
  @video %{id: 2, name: "Video"}
  @pdf %{id: 3, name: "PDF"}
  @youtube_url %{id: 4, name: "YouTube URL"}

  def seed_data do
    [
      @image,
      @video,
      @pdf,
      @youtube_url
    ]
  end

  @primary_key false
  schema "stories_attachment_types" do
    field :id, :integer, primary_key: true
    field :name, :string

    timestamps()
  end

  @doc false
  def changeset(attachment_type, params) do
    attachment_type
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

  def pdf do
    @pdf
  end

  def youtube_url do
    @youtube_url
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
