defmodule BnApis.Feedbacks.FeedbackRatingReason do
  use Ecto.Schema
  import Ecto.Changeset
  alias BnApis.Feedbacks.FeedbackRating

  @primary_key false
  schema "feedbacks_ratings_reasons" do
    field :id, :integer, primary_key: true
    field :name, :string
    belongs_to :feedback_rating, FeedbackRating

    timestamps()
  end

  # @bad %{id: 1, name: "Bad"}
  # @good %{id: 2, name: "Good"}
  def seed_data do
    [
      %{
        id: 1,
        name: "One of more listings had expired",
        feedback_rating_id: 1
      },
      %{
        id: 2,
        name: "Broker was rude",
        feedback_rating_id: 1
      },
      %{
        id: 3,
        name: "Broker did not answer",
        feedback_rating_id: 1
      },
      %{
        id: 4,
        name: "My reason is not listed",
        feedback_rating_id: 1
      },
      %{
        id: 5,
        name: "Deal Successful",
        feedback_rating_id: 2
      },
      %{
        id: 6,
        name: "Match was perfect",
        feedback_rating_id: 2
      },
      %{
        id: 7,
        name: "Broker was excellent",
        feedback_rating_id: 2
      },
      %{
        id: 8,
        name: "My reason is not listed",
        feedback_rating_id: 2
      }
    ]
  end

  @fields [:id, :name, :feedback_rating_id]
  def changeset(status, params) do
    status
    |> cast(params, @fields)
    |> validate_required(@fields)
    |> unique_constraint(:name)
  end

  def changeset(params) do
    %__MODULE__{}
    |> changeset(params)
  end
end
