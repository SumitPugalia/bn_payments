defmodule BnApis.Events.Event do
  use Ecto.Schema
  import Ecto.Changeset

  alias BnApis.Repo
  alias BnApis.Events.Event

  schema "events" do
    field :uuid, Ecto.UUID, read_after_writes: true
    field :type, :string
    field :action, :string
    field :data, :map
    field :user_id, :integer

    timestamps()
  end

  @required [:type, :action, :user_id]
  @fields @required ++ [:data]

  @doc false
  def changeset(event, attrs) do
    event
    |> cast(attrs, @fields)
    |> validate_required(@required)
  end

  def create_event(attrs) do
    %Event{}
    |> Event.changeset(attrs)
    |> Repo.insert()
  end
end
