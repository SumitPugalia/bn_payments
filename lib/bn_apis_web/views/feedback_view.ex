defmodule BnApisWeb.FeedbackView do
  use BnApisWeb, :view
  alias BnApisWeb.FeedbackView

  def render("index.json", %{feedbacks: feedbacks}) do
    %{data: render_many(feedbacks, FeedbackView, "feedback.json")}
  end

  def render("show.json", %{feedback: feedback}) do
    %{data: render_one(feedback, FeedbackView, "feedback.json")}
  end

  def render("feedback.json", %{feedback: feedback}) do
    %{
      id: feedback.id
    }
  end

  def render("feedback_ratings.json", %{feedback_ratings: feedback_ratings}) do
    %{feedback_ratings: render_many(feedback_ratings, FeedbackView, "feedback_rating.json", as: :feedback_rating)}
  end

  def render("feedback_rating.json", %{feedback_rating: feedback_rating}) do
    %{
      id: feedback_rating.id,
      name: feedback_rating.name,
      reasons: render_many(feedback_rating.reasons, FeedbackView, "feedback_reason.json", as: :feedback_reason)
    }
  end

  def render("feedback_reason.json", %{feedback_reason: feedback_reason}) do
    %{
      id: feedback_reason.id,
      name: feedback_reason.name
    }
  end
end
