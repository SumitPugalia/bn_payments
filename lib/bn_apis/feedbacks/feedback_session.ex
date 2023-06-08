defmodule BnApis.Feedbacks.FeedbackSession do
  use Ecto.Schema
  import Ecto.Changeset

  schema "feedbacks_sessions" do
    field :uuid, Ecto.UUID, read_after_writes: true
    field :initiated_by_id, :id
    field :start_time, :naive_datetime
    field :source, :map

    timestamps()
  end

  @fields [:initiated_by_id, :source, :start_time]

  @doc false
  def changeset(feedback_session, attrs) do
    feedback_session
    |> cast(attrs, @fields)
    |> validate_required([:initiated_by_id])
    |> unique_constraint([:initiated_by_id, :start_time],
      name: :session_init_start_time,
      message: "Found duplicate combination of initiated by and start time"
    )
  end
end
