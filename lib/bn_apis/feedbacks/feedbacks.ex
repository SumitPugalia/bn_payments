defmodule BnApis.Feedbacks do
  @moduledoc """
  The Feedbacks context.
  """

  import Ecto.Query, warn: false
  alias BnApis.Repo

  alias BnApis.Feedbacks.FeedbackRating
  alias BnApis.Accounts
  alias BnApis.Accounts.Credential
  alias BnApis.Helpers.FcmNotification
  alias BnApisWeb.Helpers.PhoneHelper, as: Phone

  @doc """
  Returns the list of feedbacks_ratings.

  ## Examples

      iex> list_feedbacks_ratings()
      [%FeedbackRating{}, ...]

  """
  def list_feedbacks_ratings do
    Repo.all(FeedbackRating) |> Repo.preload([:reasons])
  end

  @doc """
  Gets a single feedback_rating.

  Raises `Ecto.NoResultsError` if the Feedback rating does not exist.

  ## Examples

      iex> get_feedback_rating!(123)
      %FeedbackRating{}

      iex> get_feedback_rating!(456)
      ** (Ecto.NoResultsError)

  """
  def get_feedback_rating!(id), do: Repo.get!(FeedbackRating, id)

  @doc """
  Creates a feedback_rating.

  ## Examples

      iex> create_feedback_rating(%{field: value})
      {:ok, %FeedbackRating{}}

      iex> create_feedback_rating(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_feedback_rating(attrs \\ %{}) do
    %FeedbackRating{}
    |> FeedbackRating.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a feedback_rating.

  ## Examples

      iex> update_feedback_rating(feedback_rating, %{field: new_value})
      {:ok, %FeedbackRating{}}

      iex> update_feedback_rating(feedback_rating, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_feedback_rating(%FeedbackRating{} = feedback_rating, attrs) do
    feedback_rating
    |> FeedbackRating.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a FeedbackRating.

  ## Examples

      iex> delete_feedback_rating(feedback_rating)
      {:ok, %FeedbackRating{}}

      iex> delete_feedback_rating(feedback_rating)
      {:error, %Ecto.Changeset{}}

  """
  def delete_feedback_rating(%FeedbackRating{} = feedback_rating) do
    Repo.delete(feedback_rating)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking feedback_rating changes.

  ## Examples

      iex> change_feedback_rating(feedback_rating)
      %Ecto.Changeset{source: %FeedbackRating{}}

  """
  def change_feedback_rating(%FeedbackRating{} = feedback_rating) do
    FeedbackRating.changeset(feedback_rating, %{})
  end

  alias BnApis.Feedbacks.FeedbackRatingReason

  @doc """
  Returns the list of feedbacks_ratings_reasons.

  ## Examples

      iex> list_feedbacks_ratings_reasons()
      [%FeedbackRatingReason{}, ...]

  """
  def list_feedbacks_ratings_reasons do
    Repo.all(FeedbackRatingReason)
  end

  @doc """
  Gets a single feedback_rating_reason.

  Raises `Ecto.NoResultsError` if the Feedback rating reason does not exist.

  ## Examples

      iex> get_feedback_rating_reason!(123)
      %FeedbackRatingReason{}

      iex> get_feedback_rating_reason!(456)
      ** (Ecto.NoResultsError)

  """
  def get_feedback_rating_reason!(id), do: Repo.get!(FeedbackRatingReason, id)

  @doc """
  Creates a feedback_rating_reason.

  ## Examples

      iex> create_feedback_rating_reason(%{field: value})
      {:ok, %FeedbackRatingReason{}}

      iex> create_feedback_rating_reason(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_feedback_rating_reason(attrs \\ %{}) do
    %FeedbackRatingReason{}
    |> FeedbackRatingReason.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a feedback_rating_reason.

  ## Examples

      iex> update_feedback_rating_reason(feedback_rating_reason, %{field: new_value})
      {:ok, %FeedbackRatingReason{}}

      iex> update_feedback_rating_reason(feedback_rating_reason, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_feedback_rating_reason(%FeedbackRatingReason{} = feedback_rating_reason, attrs) do
    feedback_rating_reason
    |> FeedbackRatingReason.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a FeedbackRatingReason.

  ## Examples

      iex> delete_feedback_rating_reason(feedback_rating_reason)
      {:ok, %FeedbackRatingReason{}}

      iex> delete_feedback_rating_reason(feedback_rating_reason)
      {:error, %Ecto.Changeset{}}

  """
  def delete_feedback_rating_reason(%FeedbackRatingReason{} = feedback_rating_reason) do
    Repo.delete(feedback_rating_reason)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking feedback_rating_reason changes.

  ## Examples

      iex> change_feedback_rating_reason(feedback_rating_reason)
      %Ecto.Changeset{source: %FeedbackRatingReason{}}

  """
  def change_feedback_rating_reason(%FeedbackRatingReason{} = feedback_rating_reason) do
    FeedbackRatingReason.changeset(feedback_rating_reason, %{})
  end

  alias BnApis.Feedbacks.FeedbackSession

  @doc """
  Returns the list of feedbacks_sessions.

  ## Examples

      iex> list_feedbacks_sessions()
      [%FeedbackSession{}, ...]

  """
  def list_feedbacks_sessions do
    Repo.all(FeedbackSession)
  end

  @doc """
  Gets a single feedback_session.

  Raises `Ecto.NoResultsError` if the Feedback session does not exist.

  ## Examples

      iex> get_feedback_session!(123)
      %FeedbackSession{}

      iex> get_feedback_session!(456)
      ** (Ecto.NoResultsError)

  """
  def get_feedback_session!(id), do: Repo.get!(FeedbackSession, id)
  def get_feedback_session_by_uuid!(uuid), do: Repo.get_by!(FeedbackSession, uuid: uuid)

  @doc """
  Creates a feedback_session.

  ## Examples

      iex> create_feedback_session(%{field: value})
      {:ok, %FeedbackSession{}}

      iex> create_feedback_session(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_feedback_session(attrs \\ %{}) do
    %FeedbackSession{}
    |> FeedbackSession.changeset(attrs)
    |> Repo.insert()
  end

  def create_or_get_feedback_session(params = %{initiated_by_id: initiated_by_id, start_time: start_time, source: source}) do
    query =
      FeedbackSession
      |> where(initiated_by_id: ^initiated_by_id)
      |> where(start_time: ^start_time)

    case query |> Repo.one() do
      nil ->
        source =
          case source |> Poison.decode() do
            {:ok, value} ->
              value

            _ ->
              nil
          end

        params = %{params | source: source}

        %FeedbackSession{}
        |> FeedbackSession.changeset(params)
        |> Repo.insert()

      feedback_session ->
        {:ok, feedback_session}
    end
  end

  @doc """
  Updates a feedback_session.

  ## Examples

      iex> update_feedback_session(feedback_session, %{field: new_value})
      {:ok, %FeedbackSession{}}

      iex> update_feedback_session(feedback_session, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_feedback_session(%FeedbackSession{} = feedback_session, attrs) do
    feedback_session
    |> FeedbackSession.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a FeedbackSession.

  ## Examples

      iex> delete_feedback_session(feedback_session)
      {:ok, %FeedbackSession{}}

      iex> delete_feedback_session(feedback_session)
      {:error, %Ecto.Changeset{}}

  """
  def delete_feedback_session(%FeedbackSession{} = feedback_session) do
    Repo.delete(feedback_session)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking feedback_session changes.

  ## Examples

      iex> change_feedback_session(feedback_session)
      %Ecto.Changeset{source: %FeedbackSession{}}

  """
  def change_feedback_session(%FeedbackSession{} = feedback_session) do
    FeedbackSession.changeset(feedback_session, %{})
  end

  alias BnApis.Feedbacks.Feedback

  @doc """
  Returns the list of feedbacks.

  ## Examples

      iex> list_feedbacks()
      [%Feedback{}, ...]

  """
  def list_feedbacks do
    Repo.all(Feedback)
  end

  @doc """
  Gets a single feedback.

  Raises `Ecto.NoResultsError` if the Feedback does not exist.

  ## Examples

      iex> get_feedback!(123)
      %Feedback{}

      iex> get_feedback!(456)
      ** (Ecto.NoResultsError)

  """
  def get_feedback!(id), do: Repo.get!(Feedback, id)

  @doc """
  Creates a feedback.

  ## Examples

      iex> create_feedback(%{field: value})
      {:ok, %Feedback{}}

      iex> create_feedback(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_feedback(attrs \\ %{}) do
    %Feedback{}
    |> Feedback.changeset(attrs)
    |> Repo.insert()
  end

  def construct_feedback(
        params = %{
          "feedback_session_id" => feedback_session_uuid,
          "feedback_rating_id" => _feedback_rating_id,
          "feedback_rating_reason_id" => _feedback_rating_reason_id,
          "feedback_for_id" => feedback_for_uuid,
          "feedback_by_id" => _user_id
        }
      ) do
    feedback_for_cred = Accounts.get_credential_by_uuid(feedback_for_uuid)
    feedback_session = Repo.get_by(FeedbackSession, uuid: feedback_session_uuid)

    cond do
      is_nil(feedback_session) ->
        {:error, "Feedback session Id invalid!"}

      is_nil(feedback_for_cred) ->
        {:error, "feedback_for_id invalid!"}

      true ->
        update_params = %{
          "feedback_session_id" => feedback_session.id,
          "feedback_for_id" => feedback_for_cred.id
        }

        params = params |> Map.merge(update_params)
        create_feedback(params)
    end
  end

  def send_push(
        params = %{
          "from_uuid" => from_uuid,
          "from_phone_number" => from_phone_number,
          "source" => _source,
          "receiver_phone_number" => receiver_phone_number,
          "feedback_session_uuid" => feedback_session_uuid
        }
      ) do
    with {:ok, phone_number, country_code} <-
           Phone.parse_phone_number(%{"phone_number" => receiver_phone_number, "country_code" => params["country_code"]}),
         %Credential{} = credential <- Accounts.get_active_credential_by_phone(phone_number, country_code) do
      if credential.fcm_id do
        data = %{
          "feedback_id" => feedback_session_uuid,
          "from_id" => from_uuid,
          "from_phone_number" => from_phone_number
        }

        type = "NOTIFY_FEEDBACK_SESSION"

        FcmNotification.send_push(
          credential.fcm_id,
          %{data: data, type: type},
          credential.id,
          credential.notification_platform
        )
      else
        {:error, "FCM id not present for user!"}
      end
    else
      nil ->
        {:error, "receiver_user_id not valid!"}

      {:error, _} = error ->
        error
    end
  end

  @doc """
  Updates a feedback.

  ## Examples

      iex> update_feedback(feedback, %{field: new_value})
      {:ok, %Feedback{}}

      iex> update_feedback(feedback, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_feedback(%Feedback{} = feedback, attrs) do
    feedback
    |> Feedback.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a Feedback.

  ## Examples

      iex> delete_feedback(feedback)
      {:ok, %Feedback{}}

      iex> delete_feedback(feedback)
      {:error, %Ecto.Changeset{}}

  """
  def delete_feedback(%Feedback{} = feedback) do
    Repo.delete(feedback)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking feedback changes.

  ## Examples

      iex> change_feedback(feedback)
      %Ecto.Changeset{source: %Feedback{}}

  """
  def change_feedback(%Feedback{} = feedback) do
    Feedback.changeset(feedback, %{})
  end
end
