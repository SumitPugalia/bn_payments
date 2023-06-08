defmodule BnApis.Stories.UserFavourite do
  use Ecto.Schema
  import Ecto.Changeset

  alias BnApis.Accounts.Credential
  alias BnApis.Stories.Story

  schema "stories_user_favourites" do
    field :timestamp, :naive_datetime

    belongs_to :credential, Credential
    belongs_to :story, Story

    timestamps()
  end

  @fields [:credential_id, :story_id, :timestamp]
  @required_fields [:credential_id, :story_id]

  @doc false
  def changeset(user_favourite, attrs \\ %{}) do
    user_favourite
    |> cast(attrs, @fields)
    |> validate_required(@required_fields)
  end
end
