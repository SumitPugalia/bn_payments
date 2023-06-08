defmodule BnApis.Feedbacks.Feedback do
  use Ecto.Schema
  import Ecto.Changeset

  alias BnApis.Accounts.Credential
  alias BnApis.Feedbacks.FeedbackSession

  schema "feedbacks" do
    field :feedback_rating_id, :id
    field :feedback_rating_reason_id, :id
    belongs_to :feedback_session, FeedbackSession
    belongs_to :feedback_by, Credential
    belongs_to :feedback_for, Credential

    timestamps()
  end

  @fields [:feedback_session_id, :feedback_rating_id, :feedback_rating_reason_id, :feedback_by_id, :feedback_for_id]
  @doc false
  def changeset(feedback, attrs) do
    feedback
    |> cast(attrs, @fields)
    |> validate_required(@fields)
    |> unique_constraint(:name, name: :feedback_uniqueness_index)
    |> check_constraint(:feedback_ids,
      name: :feedback_by_and_for_should_not_be_identical,
      message: "Feedback by and for should not be identical!"
    )
  end
end
