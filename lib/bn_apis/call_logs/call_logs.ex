defmodule BnApis.CallLogs do
  @moduledoc """
  The CallLogs context.
  """

  import Ecto.Query, warn: false
  alias BnApis.Repo
  alias BnApis.{Accounts, Contacts}
  alias BnApis.Accounts.Credential
  alias BnApisWeb.Helpers.PhoneHelper, as: Phone
  alias BnApis.Helpers.{Time, FcmNotification}
  alias BnApis.Stories.StoryCallLog

  @logs_per_page 30

  alias BnApis.CallLogs.CallLogCallStatus

  def logs_per_page, do: @logs_per_page

  @doc """
  Returns the list of call_logs_call_statuses.

  ## Examples

      iex> list_call_logs_call_statuses()
      [%CallLogCallStatus{}, ...]

  """
  def list_call_logs_call_statuses do
    Repo.all(CallLogCallStatus)
  end

  @doc """
  Gets a single call_log_call_status.

  Raises `Ecto.NoResultsError` if the Call log call status does not exist.

  ## Examples

      iex> get_call_log_call_status!(123)
      %CallLogCallStatus{}

      iex> get_call_log_call_status!(456)
      ** (Ecto.NoResultsError)

  """
  def get_call_log_call_status!(id), do: Repo.get!(CallLogCallStatus, id)

  @doc """
  Creates a call_log_call_status.

  ## Examples

      iex> create_call_log_call_status(%{field: value})
      {:ok, %CallLogCallStatus{}}

      iex> create_call_log_call_status(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_call_log_call_status(attrs \\ %{}) do
    CallLogCallStatus.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a call_log_call_status.

  ## Examples

      iex> update_call_log_call_status(call_log_call_status, %{field: new_value})
      {:ok, %CallLogCallStatus{}}

      iex> update_call_log_call_status(call_log_call_status, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_call_log_call_status(%CallLogCallStatus{} = call_log_call_status, attrs) do
    call_log_call_status
    |> CallLogCallStatus.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a CallLogCallStatus.

  ## Examples

      iex> delete_call_log_call_status(call_log_call_status)
      {:ok, %CallLogCallStatus{}}

      iex> delete_call_log_call_status(call_log_call_status)
      {:error, %Ecto.Changeset{}}

  """
  def delete_call_log_call_status(%CallLogCallStatus{} = call_log_call_status) do
    Repo.delete(call_log_call_status)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking call_log_call_status changes.

  ## Examples

      iex> change_call_log_call_status(call_log_call_status)
      %Ecto.Changeset{source: %CallLogCallStatus{}}

  """
  def change_call_log_call_status(%CallLogCallStatus{} = call_log_call_status) do
    CallLogCallStatus.changeset(call_log_call_status, %{})
  end

  alias BnApis.CallLogs.CallLog

  @doc """
  Returns the list of call_logs.

  ## Examples

      iex> list_call_logs()
      [%CallLog{}, ...]

  """
  def list_call_logs do
    Repo.all(CallLog)
  end

  @doc """
  Gets a single call_log.

  Raises `Ecto.NoResultsError` if the Call log does not exist.

  ## Examples

      iex> get_call_log!(123)
      %CallLog{}

      iex> get_call_log!(456)
      ** (Ecto.NoResultsError)

  """
  def get_call_log!(id), do: Repo.get!(CallLog, id)
  def get_call_log_details(id, _phone_number), do: CallLog.call_log_query(id) |> Repo.one()

  # @doc """
  # Check in sequence
  # 1. Signed up users
  # 2. Broker Universe
  # """
  defp call_log_professional?(phone_number, country_code) do
    case Accounts.get_active_credential_by_phone(phone_number, country_code) do
      nil ->
        case Contacts.get_broker_from_universe_by_phone(phone_number, country_code) do
          nil ->
            false

          _broker ->
            true
        end

      _cred ->
        true
    end
  end

  @doc """
  Creates a call_log.

  ## Examples

      iex> create_call_log(%{field: value})
      {:ok, %CallLog{}}

      iex> create_call_log(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_call_log(attrs \\ %{})

  def create_call_log(attrs = %{"log_uuid" => log_uuid}) do
    with {:ok, phone_number, country_code} <- Phone.parse_phone_number(attrs),
         %CallLog{} = associated_call_log <- Repo.get_by(CallLog, uuid: log_uuid) do
      is_call_log_professional = call_log_professional?(phone_number, country_code)

      attrs =
        attrs
        |> Map.merge(%{
          "start_time" => attrs["start_time"] |> Time.epoch_to_naive(),
          "end_time" => attrs["end_time"] |> Time.epoch_to_naive(),
          "is_professional" => is_call_log_professional,
          "call_log_id" => associated_call_log.id,
          "phone_number" => phone_number,
          "country_code" => country_code
        })

      %CallLog{}
      |> CallLog.changeset(attrs)
      |> Repo.insert()
    else
      nil ->
        {:error, "Log not found!"}

      {:error, _reason} = error ->
        error
    end
  end

  def create_call_log(attrs) do
    case Phone.parse_phone_number(attrs) do
      {:ok, phone_number, country_code} ->
        is_call_log_professional = call_log_professional?(phone_number, country_code)

        attrs =
          attrs
          |> Map.merge(%{
            "start_time" => attrs["start_time"] |> Time.epoch_to_naive(),
            "is_professional" => is_call_log_professional,
            "phone_number" => phone_number,
            "country_code" => country_code
          })

        %CallLog{}
        |> CallLog.changeset(attrs)
        |> Repo.insert()

      {:error, _reason} = error ->
        error
    end
  end

  @doc """
  Updates a call_log.

  ## Examples

      iex> update_call_log(call_log, %{field: new_value})
      {:ok, %CallLog{}}

      iex> update_call_log(call_log, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_call_log(%CallLog{} = call_log, attrs) do
    call_log
    |> CallLog.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a CallLog.

  ## Examples

      iex> delete_call_log(call_log)
      {:ok, %CallLog{}}

      iex> delete_call_log(call_log)
      {:error, %Ecto.Changeset{}}

  """
  def delete_call_log(%CallLog{} = call_log) do
    Repo.delete(call_log)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking call_log changes.

  ## Examples

      iex> change_call_log(call_log)
      %Ecto.Changeset{source: %CallLog{}}

  """
  def change_call_log(%CallLog{} = call_log) do
    CallLog.changeset(call_log, %{})
  end

  def fetch_all_call_logs(user_id, page) do
    call_logs_query = CallLog.all_call_logs_query(user_id)
    story_logs_query = StoryCallLog.get_call_logs(user_id)

    total_count = (call_logs_query |> CallLog.get_count()) + (story_logs_query |> StoryCallLog.get_count())
    has_more_call_logs = page < Float.ceil(total_count / @logs_per_page)

    call_logs = call_logs_query |> CallLog.select_query() |> Repo.all()
    story_call_logs = StoryCallLog.get_call_logs(user_id) |> Repo.all()

    call_logs =
      (call_logs ++ story_call_logs)
      |> Enum.sort_by(fn log -> log.inserted_at |> Time.naive_to_epoch() end, &>=/2)
      |> Enum.slice(((page - 1) * @logs_per_page)..(page * @logs_per_page - 1))

    {call_logs, has_more_call_logs}
  end

  @doc """
  Returns latest 3 logs with broker
  """
  def call_logs_with_broker(user_id, broker_phone_number) do
    query = CallLog.call_logs_with_broker_query(user_id, broker_phone_number)
    query |> CallLog.select_query() |> Repo.all()
  end

  def send_push(
        params = %{
          "from_uuid" => from_uuid,
          "from_phone_number" => from_phone_number,
          "receiver_phone_number" => receiver_phone_number,
          "log_uuid" => log_uuid,
          "call_start_time" => call_start_time
        }
      ) do
    with {:ok, phone_number, country_code} <-
           Phone.parse_phone_number(%{"phone_number" => receiver_phone_number, "country_code" => params["country_code"]}),
         %Credential{} = credential <- Accounts.get_active_credential_by_phone(phone_number, country_code) do
      if credential.fcm_id do
        data = %{
          "log_uuid" => log_uuid,
          "from_uuid" => from_uuid,
          "from_phone_number" => from_phone_number,
          "call_start_time" => call_start_time
        }

        type = "NOTIFY_INITIATOR_CALL_START_TIME"

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
    end
  end

  def save_log_end_time(log_uuid, params) do
    case Repo.get_by(CallLog, uuid: log_uuid) do
      nil ->
        {:error, "Log not found!"}

      call_log ->
        params =
          params
          |> Map.merge(%{
            "end_time" => params["end_time"] |> Time.epoch_to_naive()
          })

        call_log = call_log |> CallLog.changeset(params) |> Repo.update!()
        {:ok, call_log}
    end
  end

  def find_incoming_log(log_id) do
    Repo.get_by(CallLog, call_log_id: log_id)
  end

  @doc """
  returns true if receiver's call end_time and initiator's end_time difference is 0 or +2 / -2 seconds
  and receiver's call ringing start time is greater than initiator's call start time
  """
  # Incoming/Receiver
  def is_valid_for_feedback_collection(call_log, receiver_call_log = %{call_status_id: 2}) do
    diff = NaiveDateTime.diff(call_log.end_time, receiver_call_log.end_time, :second)
    updated_at_diff = NaiveDateTime.diff(call_log.updated_at, receiver_call_log.updated_at, :second)
    start_time_diff = NaiveDateTime.diff(receiver_call_log.start_time, call_log.start_time, :second)
    is_valid = ((diff >= -2 and diff <= 2) or (updated_at_diff >= -3 and updated_at_diff <= 3)) and start_time_diff >= 0
    is_valid
  end

  def is_valid_for_feedback_collection(_call_log, _receiver_call_log), do: false
end
