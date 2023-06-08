defmodule BnApisWeb.Plugs.SessionPlug do
  import Plug.Conn

  alias BnApis.Repo
  alias BnApis.Accounts.{ProfileType, Credential}
  alias BnApis.Helpers.{Token, Connection}

  def init(opts) do
    opts
  end

  defp is_admin_path(conn) do
    conn.request_path =~ ~r/^\/admin\// or conn.request_path =~ ~r/^\/on_ground\// or conn.request_path =~ ~r/.*.api\/organizations\/filter$/
  end

  def call(conn, _opts) do
    _origin = conn |> get_req_header("origin")

    session_token =
      if Connection.bearer_auth?(conn) do
        Connection.bearer_auth_creds(conn)
      else
        conn |> get_req_header("session-token") |> List.first()
      end

    case validate_token(conn, session_token, conn |> is_admin_path) do
      {:error, message} ->
        conn
        |> send_resp(401, Poison.encode!(%{message: message, invalidSession: true}))
        |> halt

      {:ok, session_data} ->
        # Session data will be available at conn.assigns[:user]
        conn
        |> assign(:user, session_data)
    end
  end

  defp update_last_active_at(user_id) do
    Credential.update_last_active_at_query(user_id) |> Repo.update_all([], [])
  end

  defp update_app_version(user_id, app_version, device_info) do
    Credential.update_app_version(user_id, app_version, device_info) |> Repo.update_all([], [])
  end

  # @doc """
  # Used to validate session when called from a accounts.anarock page
  # """
  defp validate_token(_conn, session_token, true) when byte_size(session_token) > 0 do
    profile_type_id = ProfileType.employee().id
    session_data = Token.get_token_data(session_token, profile_type_id)

    case session_data do
      %{"user_id" => _user_id} ->
        {:ok, session_data}

      _ ->
        {:error, "You are not authorized to make this call"}
    end
  end

  # @doc """
  # Used to validate session when called from native mobile
  # as Authentication: Bearer session_token
  # """
  defp validate_token(conn, session_token, _is_admin) when byte_size(session_token) > 0 do
    profile_type_id = ProfileType.broker().id
    session_data = Token.get_token_data(session_token, profile_type_id, true)

    case session_data do
      %{"active" => false} ->
        {:error, "You are not authorized to make this call"}

      %{"user_id" => user_id} ->
        update_last_active_at(user_id)
        app_version = conn |> get_app_version()
        device_info = conn |> get_app_device_info()
        update_app_version(user_id, app_version, device_info)
        {:ok, session_data}

      _ ->
        {:error, "You are not authorized to make this call"}
    end
  end

  defp validate_token(_, _, _), do: {:error, "You are not authorized to make this call"}

  defp get_app_version(conn) do
    try do
      conn
      |> get_req_header("x-extended-user-agent")
      |> List.first()
      |> String.split("|")
      |> List.first()
      |> String.split(":")
      |> List.last()
    rescue
      _ ->
        nil
    end
  end

  defp get_app_device_info(conn) do
    try do
      conn
      |> get_req_header("x-extended-user-agent")
      |> List.first()
      |> String.split("|")
      |> Enum.reduce(%{}, fn item, acc ->
        split_item = item |> String.split(":")
        Map.put(acc, split_item |> List.first(), split_item |> List.last())
      end)
    rescue
      _ ->
        %{}
    end
  end
end
