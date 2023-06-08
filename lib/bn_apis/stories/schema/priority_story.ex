defmodule BnApis.Stories.Schema.PriorityStory do
  use Ecto.Schema

  import Ecto.Changeset
  alias BnApis.Stories.Story
  alias BnApis.Places.City

  schema "priority_stories" do
    field(:active, :boolean, default: true)
    field(:priority, :integer)

    belongs_to(:stories, Story, foreign_key: :story_id, references: :id)
    belongs_to(:cities, City, foreign_key: :city_id, references: :id)

    timestamps()
  end

  @required_fields [:story_id, :city_id, :active, :priority]

  def changeset(priority_story, attrs) do
    priority_story
    |> cast(attrs, @required_fields)
    |> validate_required(@required_fields)
    |> validate_inclusion(:priority, [1, 2, 3, 4, 5])
    |> foreign_key_constraint(:story_id)
    |> foreign_key_constraint(:city_id)
    |> unique_constraint(:unique_active_priority_in_city,
      name: :unique_active_priority_in_city_index,
      message: "An active record with same city and priority already exists."
    )
    |> unique_constraint(:unique_active_priority_story_in_city,
      name: :unique_active_priority_story_in_city_index,
      message: "An active priority story with same story_id already exists in the city."
    )
  end
end
