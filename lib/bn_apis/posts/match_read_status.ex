defmodule BnApis.Posts.MatchReadStatus do
  use Ecto.Schema
  import Ecto.Changeset

  schema "match_read_statuses" do
    field :read, :boolean, default: false
    field :user_id, :id
    field :rental_matches_id, :id
    field :resale_matches_id, :id

    timestamps()
  end

  @doc false
  def changeset(match_read_status, attrs) do
    match_read_status
    |> cast(attrs, [:read])
    |> validate_required([:read])
  end
end
