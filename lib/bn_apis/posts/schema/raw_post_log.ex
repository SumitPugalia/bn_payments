defmodule BnApis.Posts.Schema.RawPostLog do
  use Ecto.Schema
  import Ecto.Changeset

  schema "raw_post_logs" do
    field :changes, :map
    field :user_id, :integer
    field :user_type, :string
    field :raw_entity_type, :string
    field :raw_entity_id, :id

    timestamps()
  end

  @optional [:user_id, :user_type]
  @required [:changes, :raw_entity_type, :raw_entity_id]
  @doc false
  def changeset(raw_post_log, attrs) do
    raw_post_log
    |> cast(attrs, @required ++ @optional)
    |> validate_required(@required)
  end
end
