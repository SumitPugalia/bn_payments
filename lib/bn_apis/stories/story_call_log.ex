defmodule BnApis.Stories.StoryCallLog do
  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query

  alias BnApis.Stories.{Story, StoryCallLog}
  alias BnApis.Developers.Developer
  alias BnApis.Accounts.Credential

  schema "stories_call_logs" do
    field :uuid, Ecto.UUID, read_after_writes: true
    field :phone_number, :string
    field :country_code, :string, default: "+91"
    field :end_time, :naive_datetime
    field :start_time, :naive_datetime

    belongs_to :story, Story
    timestamps()
  end

  @fields [:phone_number, :country_code, :start_time, :end_time, :story_id]
  @required_fields [:phone_number, :start_time]

  @doc false
  def changeset(story_call_log, attrs \\ %{}) do
    story_call_log
    |> cast(attrs, @fields)
    |> validate_required(@required_fields)
    |> foreign_key_constraint(:story_id)
  end

  def get_call_logs(user_id) do
    StoryCallLog
    |> order_by(desc: :inserted_at)
    |> join(:inner, [scl], cred in Credential,
      on:
        cred.phone_number == scl.phone_number and cred.country_code == scl.country_code and cred.active == true and
          cred.id == ^user_id
    )
    |> join(:left, [scl, cred], s in Story, on: s.id == scl.story_id)
    |> join(:left, [scl, cred, s], d in Developer, on: s.developer_id == d.id)
    |> select([scl, c, story, developer], %{
      inserted_at: scl.inserted_at,
      phone_number: scl.phone_number,
      uuid: scl.uuid,
      start_time: scl.start_time,
      # Default Outgoing call
      call_status_id: 3,
      type: "story",
      contact_details: %{
        uuid: story.uuid,
        profile_pic_url: story.image_url,
        phone_number: story.phone_number,
        org_name: developer.name,
        name: story.name
      }
    })
  end

  def get_count(query) do
    query
    |> BnApis.Repo.aggregate(:count, :id)
  end
end
