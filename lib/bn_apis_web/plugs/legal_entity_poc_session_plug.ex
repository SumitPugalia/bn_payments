defmodule BnApisWeb.Plugs.LegalEntityPocSession do
  import Plug.Conn

  alias BnApis.Repo
  alias BnApis.Schemas.LegalEntityPoc
  alias BnApis.Accounts.ProfileType
  alias BnApis.Helpers.{Token, Connection}

  def init(opts) do
    opts
  end

  defp is_admin_path(conn) do
    conn.request_path =~ ~r/^\/admin\//
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

      {:ok, session_data} ->
        # Session data will be available at conn.assigns[:user]
        conn
        |> assign(:user, session_data)
    end
  end

  defp update_last_active_at(user_id) do
    LegalEntityPoc.update_last_active_at_query(user_id) |> Repo.update_all([], [])
  end

  # @doc """
  # Used to validate session when called from a accounts.anarock page
  # """
  defp validate_token(conn, session_token) when byte_size(session_token) > 0 do
    profile_type_id = if is_admin_path(conn), do: ProfileType.legal_entity_poc_admin().id, else: ProfileType.legal_entity_poc().id

    session_data = Token.get_token_data(session_token, profile_type_id)

    case session_data do
      %{"user_id" => user_id} ->
        update_last_active_at(user_id)
        {:ok, session_data}

      _ ->
        {:error, "You are not authorized to make this call"}
    end
  end

  defp validate_token(_, _), do: {:error, "You are not authorized to make this call"}
end
