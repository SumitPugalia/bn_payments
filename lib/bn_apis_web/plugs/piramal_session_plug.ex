defmodule BnApisWeb.Plugs.PiramalSessionPlug do
  import Plug.Conn

  alias BnApis.Helpers.ApplicationHelper
  alias BnApis.Helpers.Connection

  def init(options) do
    options
  end

  def call(conn, _opts) do
    _origin = conn |> get_req_header("origin")

    session_token =
      if Connection.bearer_auth?(conn) do
        Connection.bearer_auth_creds(conn)
      else
        conn |> get_req_header("session-token") |> List.first()
      end

    case validate_token(conn, session_token) do
      {:error, message} ->
        conn
        |> send_resp(401, Poison.encode!(%{message: message, invalidSession: true}))
        |> halt

      {:ok, _session_data} ->
        user_data = %{user_id: 0, user_type: "Piramal User"}

        conn
        |> assign(:user, user_data)
    end
  end

  # @doc """
  # Used to validate session based on the authentication key
  # """
  defp validate_token(_, nil), do: {:error, "You are not authorized to make this call"}

  defp validate_token(_conn, session_token) do
    piramal_authentication_key = ApplicationHelper.get_piramal_authentication_key()
    valid_auth_key? = piramal_authentication_key === session_token

    case valid_auth_key? do
      true ->
        {:ok, session_token}

      _ ->
        {:error, "You are not authorized to make this call"}
    end
  end
end
