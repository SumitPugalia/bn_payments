defmodule BnApisWeb.Plugs.OngroundSessionPlug do
  import Plug.Conn

  alias BnApis.Accounts.{ProfileType}
  alias BnApis.Helpers.{Token, Connection}
  # alias BnApis.Helpers.ApplicationHelper

  def init(opts) do
    opts
  end

  defp is_admin_path(conn) do
    conn.request_path =~ ~r/^\/admin\// or conn.request_path =~ ~r/^\/on_ground\//
  end

  def call(conn, _opts) do
    _origin = conn |> get_req_header("origin")

    session_token =
      if Connection.bearer_auth?(conn) do
        Connection.bearer_auth_creds(conn)
      else
        conn |> get_req_header("session-token") |> List.first()
      end

    # if ApplicationHelper.get_onground_apis_allowed() == "false" do
    #   conn
    #     |> send_resp(401, Poison.encode!(%{message: "Please update app from playstore", invalidSession: true}))
    #     |> halt
    # else
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

    # end
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

  defp validate_token(_, _, _), do: {:error, "You are not authorized to make this call"}
end
