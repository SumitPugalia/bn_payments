defmodule BnApis.Stories.StorySection do
  use Ecto.Schema
  import Ecto.Changeset

  alias BnApis.Stories.{Story, SectionResourceType, UserSeen}

  schema "stories_sections" do
    field :uuid, Ecto.UUID, read_after_writes: true
    field :interval, :integer
    field :resource_url, :string
    field :order, :integer
    field :active, :boolean, default: true

    has_many :user_seens, UserSeen
    belongs_to :resource_type, SectionResourceType
    belongs_to :story, Story
    timestamps()
  end

  @fields [:interval, :resource_url, :resource_type_id, :story_id, :order, :active]
  @required_fields [:resource_url, :resource_type_id]

  @doc false
  def changeset(story_section, attrs \\ %{}) do
    story_section
    |> cast(attrs, @fields)
    |> validate_required(@required_fields)
    |> foreign_key_constraint(:story_id)
  end
end
