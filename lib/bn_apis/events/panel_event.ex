defmodule BnApis.Events.PanelEvent do
  use Ecto.Schema
  import Ecto.Changeset

  alias BnApis.Repo
  alias BnApis.Events.PanelEvent

  schema "panel_events" do
    field :uuid, Ecto.UUID, read_after_writes: true
    field :type, :string
    field :action, :string
    field :data, :map
    field :employees_credentials_id, :integer

    timestamps()
  end

  @required [:type, :action, :employees_credentials_id]
  @fields @required ++ [:data]

  @doc false
  def changeset(event, attrs) do
    event
    |> cast(attrs, @fields)
    |> validate_required(@required)
  end

  def create_event(attrs) do
    %PanelEvent{}
    |> PanelEvent.changeset(attrs)
    |> Repo.insert()
  end
end
