defmodule BnApis.Feedbacks.FeedbackRating do
  use Ecto.Schema
  import Ecto.Changeset

  alias BnApis.Feedbacks.FeedbackRatingReason

  @bad %{id: 1, name: "Bad"}
  @good %{id: 2, name: "Good"}

  # @primary_key false
  schema "feedbacks_ratings" do
    # field :id, :integer, primary_key: true
    field :name, :string

    has_many :reasons, FeedbackRatingReason, foreign_key: :feedback_rating_id

    timestamps()
  end

  def seed_data do
    [
      @bad,
      @good
    ]
  end

  def changeset(status, params) do
    status
    |> cast(params, [:id, :name])
    |> validate_required([:id, :name])
    |> unique_constraint(:name)
  end

  def changeset(params) do
    %__MODULE__{}
    |> changeset(params)
  end

  def bad do
    @bad
  end

  def good do
    @good
  end
end
