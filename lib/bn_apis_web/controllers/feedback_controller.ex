defmodule BnApisWeb.FeedbackController do
  use BnApisWeb, :controller

  alias BnApis.Feedbacks
  alias BnApis.Feedbacks.Feedback

  action_fallback BnApisWeb.FallbackController

  def index(conn, _params) do
    feedbacks = Feedbacks.list_feedbacks()
    render(conn, "index.json", feedbacks: feedbacks)
  end

  def create(conn, %{"feedback" => feedback_params}) do
    with {:ok, %Feedback{} = feedback} <- Feedbacks.create_feedback(feedback_params) do
      conn
      |> put_status(:created)
      |> put_resp_header("location", Routes.feedback_path(conn, :show, feedback))
      |> render("show.json", feedback: feedback)
    end
  end

  def show(conn, %{"id" => id}) do
    feedback = Feedbacks.get_feedback!(id)
    render(conn, "show.json", feedback: feedback)
  end

  def update(conn, %{"id" => id, "feedback" => feedback_params}) do
    feedback = Feedbacks.get_feedback!(id)

    with {:ok, %Feedback{} = feedback} <- Feedbacks.update_feedback(feedback, feedback_params) do
      render(conn, "show.json", feedback: feedback)
    end
  end

  def delete(conn, %{"id" => id}) do
    feedback = Feedbacks.get_feedback!(id)

    with {:ok, %Feedback{}} <- Feedbacks.delete_feedback(feedback) do
      send_resp(conn, :no_content, "")
    end
  end

  def form_data(conn, _params) do
    feedback_ratings = Feedbacks.list_feedbacks_ratings()
    render(conn, "feedback_ratings.json", feedback_ratings: feedback_ratings)
  end

  def create_feedback(
        conn,
        params = %{
          "feedback_session_id" => _feedback_session_uuid,
          "feedback_rating_id" => _feedback_rating_id,
          "feedback_rating_reason_id" => _feedback_rating_reason_id,
          "feedback_for_id" => _feedback_for_uuid
        }
      ) do
    user_id = conn.assigns[:user]["user_id"]

    params = params |> Map.merge(%{"feedback_by_id" => user_id})

    with {:ok, %Feedback{} = _feedback} <- Feedbacks.construct_feedback(params) do
      send_resp(conn, :ok, "Successfully placed your feedback!")
    end
  end
end
