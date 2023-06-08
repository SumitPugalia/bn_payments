defmodule BnApis.Stories.StoryProjectConfig do
  use Ecto.Schema
  import Ecto.Changeset

  alias BnApis.Repo

  alias BnApis.Stories.Story
  alias BnApis.Stories.StoryProjectConfig
  alias BnApis.Posts.ConfigurationType

  schema "story_project_configs" do
    field :uuid, Ecto.UUID, read_after_writes: true
    field :carpet_area, :integer
    field :starting_price, :integer
    field :active, :boolean, default: true

    belongs_to :configuration_type, ConfigurationType
    belongs_to :story, Story
    timestamps()
  end

  @fields [:active, :carpet_area, :starting_price, :configuration_type_id, :story_id]
  @required_fields [:carpet_area, :starting_price, :configuration_type_id]

  @doc false
  def changeset(story_project_config, attrs \\ %{}) do
    story_project_config
    |> cast(attrs, @fields)
    |> validate_required(@required_fields)
    |> foreign_key_constraint(:story_id)
    |> foreign_key_constraint(:configuration_type_id)
  end

  def get_by_uuid!(uuid),
    do: Repo.get_by!(StoryProjectConfig, uuid: uuid)
end
