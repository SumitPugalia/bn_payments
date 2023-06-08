defmodule BnApis.Stories.UserSeen do
  use Ecto.Schema
  import Ecto.Changeset

  schema "stories_user_seens" do
    field :timestamp, :naive_datetime
    field :credential_id, :id
    field :story_id, :id
    field :story_section_id, :id

    timestamps()
  end

  @fields [:credential_id, :story_id, :story_section_id, :timestamp]
  @required_fields [:credential_id, :story_id, :story_section_id, :timestamp]

  @doc false
  def changeset(user_seen, attrs \\ %{}) do
    user_seen
    |> cast(attrs, @fields)
    |> validate_required(@required_fields)
  end
end
