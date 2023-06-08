defmodule BnApisWeb.CallLogController do
  use BnApisWeb, :controller

  import Ecto.Query, warn: false

  alias BnApis.Repo
  alias BnApis.{CallLogs, Accounts}
  alias BnApis.CallLogs.{CallLog, CallLogCallStatus}
  alias BnApis.{Feedbacks, Posts}
  alias BnApisWeb.Helpers.PhoneHelper, as: Phone
  alias BnApis.Helpers.Connection

  action_fallback BnApisWeb.FallbackController

  def index(conn, _params) do
    call_logs = CallLogs.list_call_logs()
    render(conn, "index.json", call_logs: call_logs)
  end

  def create(conn, %{"call_log" => call_log_params}) do
    with {:ok, %CallLog{} = call_log} <- CallLogs.create_call_log(call_log_params) do
      conn
      |> put_status(:created)
      |> put_resp_header("location", Routes.call_log_path(conn, :show, call_log))
      |> render("show.json", call_log: call_log)
    end
  end

  def show(conn, %{"id" => id}) do
    call_log = CallLogs.get_call_log!(id)
    render(conn, "show.json", call_log: call_log)
  end

  def update(conn, %{"id" => id, "call_log" => call_log_params}) do
    call_log = CallLogs.get_call_log!(id)

    with {:ok, %CallLog{} = call_log} <- CallLogs.update_call_log(call_log, call_log_params) do
      render(conn, "show.json", call_log: call_log)
    end
  end

  def delete(conn, %{"id" => id}) do
    call_log = CallLogs.get_call_log!(id)

    with {:ok, %CallLog{}} <- CallLogs.delete_call_log(call_log) do
      send_resp(conn, :no_content, "")
    end
  end

  @doc """

  """
  def log_and_notify_receiver(
        conn,
        params = %{
          "phone_number" => receiver_phone_number,
          # Initiator/ Outgoing
          "call_status_id" => "3",
          "call_log_uuid" => _call_log_uuid,
          "start_time" => call_start_time
          # "sim_id" => _sim_id,
        }
      ) do
    logged_in_user = Connection.get_logged_in_user(conn)

    user_id = logged_in_user[:user_id]
    user_uuid = logged_in_user[:uuid]
    user_phone_number = logged_in_user[:phone_number]

    params = params |> Map.merge(%{"user_id" => user_id})

    with {:ok, %CallLog{} = call_log} <- CallLogs.create_call_log(params) do
      if call_log.is_professional do
        %{
          "receiver_phone_number" => receiver_phone_number,
          "call_start_time" => call_start_time,
          "from_uuid" => user_uuid,
          "from_phone_number" => user_phone_number,
          "log_uuid" => call_log.uuid
        }
        |> CallLogs.send_push()

        conn
        |> put_status(:ok)
        |> json(%{uuid: call_log.uuid})
      else
        conn
        |> put_status(:created)
        |> json(%{message: "Call log creation is not required!"})
      end
    end
  end

  @doc """

  """
  def log_end_time(
        conn,
        params = %{
          "log_uuid" => log_uuid,
          "end_time" => _call_end_time,
          "source" => source
        }
      ) do
    logged_in_user = Connection.get_logged_in_user(conn)

    user_id = logged_in_user[:user_id]
    _user_uuid = logged_in_user[:uuid]
    _user_phone_number = logged_in_user[:phone_number]

    with {:ok, call_log} <- CallLogs.save_log_end_time(log_uuid, params) do
      if call_log.is_professional do
        session_attr = %{initiated_by_id: user_id, start_time: call_log.start_time, source: source}

        case Repo.get_by(CallLog, call_log_id: call_log.id) do
          nil ->
            # :timer.sleep(5_000) # wait for 5 sec
            case Repo.get_by(CallLog, call_log_id: call_log.id) do
              nil ->
                conn
                |> put_status(:ok)
                |> json(%{feedback_session_id: nil})

              receiver_call_log ->
                conn
                |> check_and_send_session(call_log, receiver_call_log, session_attr, CallLogCallStatus.outgoing().id)
            end

          receiver_call_log ->
            conn |> check_and_send_session(call_log, receiver_call_log, session_attr, CallLogCallStatus.outgoing().id)
        end
      else
        conn
        |> put_status(:ok)
        |> json(%{message: "Saved!"})
      end
    end
  end

  defp check_and_send_session(conn, call_log, receiver_call_log, session_attr, call_status_id) do
    if CallLogs.is_valid_for_feedback_collection(call_log, receiver_call_log) do
      if call_status_id == CallLogCallStatus.outgoing().id and receiver_call_log.call_duration > 10 do
        Posts.mark_matches_read(call_log.user_id, call_log)
      end

      {:ok, feedback_session} = Feedbacks.create_or_get_feedback_session(session_attr)

      if call_status_id == CallLogCallStatus.outgoing().id do
        call_log = CallLogs.get_call_log_details(call_log.id, call_log.phone_number)
        render(conn, "call_log_with_contact.json", call_log: call_log, feedback_session_id: feedback_session.uuid)
      else
        receiver_call_log = CallLogs.get_call_log_details(receiver_call_log.id, receiver_call_log.phone_number)

        render(conn, "call_log_with_contact.json",
          call_log: receiver_call_log,
          feedback_session_id: feedback_session.uuid
        )
      end
    else
      conn
      |> put_status(:ok)
      |> json(%{feedback_session_id: nil})
    end
  end

  @doc """
    Create call log
    Requires:
      {
        phone_number: <number to which call was made / incoming call number>
        call_status_id: < Missed / Incoming / Outgoing >
        call_log_uuid: <uuid generated on client side>
        call_duration: <call duration in seconds>
        sim_id: <id of sim to/from which a call was made - string>
      }
    returns {
      {string} message
    }
  """
  def create_call_log(
        conn,
        params = %{
          "phone_number" => _phone_number,
          "call_status_id" => _call_status_id,
          "call_log_uuid" => call_log_uuid,
          "call_duration" => call_duration,
          "sim_id" => _sim_id,
          # ringing start time
          "start_time" => _call_start_time,
          "end_time" => _call_end_time,
          # server log_uuid sent through fcm
          "log_uuid" => log_uuid
        }
      ) do
    logged_in_user = Connection.get_logged_in_user(conn)

    user_id = logged_in_user[:user_id]
    _user_uuid = logged_in_user[:uuid]
    _user_phone_number = logged_in_user[:phone_number]

    uuid = if not is_nil(log_uuid) and log_uuid != "", do: log_uuid, else: call_log_uuid

    with initiator_call_log <- Repo.get_by!(CallLog, uuid: uuid),
         {:ok, phone_number, country_code} <- Phone.parse_phone_number(params),
         params = params |> Map.merge(%{"user_id" => user_id, "call_log_id" => initiator_call_log.id}),
         {:ok, receiver_call_log} <- CallLogs.create_call_log(params),
         {:ok, initiator_call_log} <- initiator_call_log |> CallLogs.update_call_log(%{call_duration: call_duration}) do
      if receiver_call_log.is_professional do
        initiator_cred = Accounts.get_active_credential_by_phone(phone_number, country_code)
        session_attr = %{initiated_by_id: initiator_cred.id, start_time: initiator_call_log.start_time, source: "{}"}

        case initiator_call_log do
          %{end_time: nil} ->
            # :timer.sleep(5_000) # wait for 5 sec
            case Repo.get_by(CallLog, uuid: uuid) do
              %{end_time: nil} ->
                conn
                |> put_status(:ok)
                |> json(%{feedback_session_id: nil})

              initiator_call_log ->
                conn
                |> check_and_send_session(
                  initiator_call_log,
                  receiver_call_log,
                  session_attr,
                  CallLogCallStatus.incoming().id
                )
            end

          initiator_call_log ->
            conn
            |> check_and_send_session(
              initiator_call_log,
              receiver_call_log,
              session_attr,
              CallLogCallStatus.incoming().id
            )
        end
      else
        conn
        |> put_status(:ok)
        |> json(%{message: "Saved!", feedback_session_id: nil})
      end
    end
  end

  @doc """
  Paginated API.
  Call Logs will be served in the order they were created.

  Response will be in this format

  returns {
    "call_logs" : [
      {
        "phone_number" => phone_number,
        "call_status_id" => call_status_id,
        "call_log_uuid" => call_log_uuid,
        "call_duration" => call_duration,
        "sim_id" => sim_id,
      },
      ...
    ],
    "more" : true/false - <Flag indicating whether server has more call logs to serve>
  }
  """
  def get_call_logs(conn, params) do
    logged_in_user = Connection.get_logged_in_user(conn)
    page = (params["p"] && params["p"] |> String.to_integer()) || 1
    user_id = logged_in_user[:user_id]

    {call_logs, has_more_call_logs} = CallLogs.fetch_all_call_logs(user_id, page)
    render(conn, "all_call_logs.json", call_logs: call_logs || [], has_more_call_logs: has_more_call_logs)
  end
end
