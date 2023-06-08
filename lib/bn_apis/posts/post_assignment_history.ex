defmodule BnApis.Posts.PostAssignmentHistory do
  use Ecto.Schema
  import Ecto.Changeset

  schema "posts_assignment_history" do
    field :end_date, :naive_datetime
    field :start_date, :naive_datetime
    field :rent_client_post_id, :id
    field :rent_property_post_id, :id
    field :resale_client_post_id, :id
    field :resale_property_post_id, :id
    field :user_id, :id
    field :changed_by_id, :id

    timestamps()
  end

  @required [:start_date, :user_id]
  @fields @required ++
            [
              :end_date,
              :changed_by_id,
              :rent_client_post_id,
              :rent_property_post_id,
              :resale_client_post_id,
              :resale_property_post_id
            ]

  @doc false
  def changeset(post_assignment_history, attrs) do
    post_assignment_history
    |> cast(attrs, @fields)
    |> validate_required(@required)
  end

  def changeset(attrs) do
    %__MODULE__{}
    |> changeset(attrs)
  end
end
