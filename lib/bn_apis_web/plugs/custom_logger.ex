defmodule BnApisWeb.Plugs.CustomLogger do
  import Plug.Conn
  require Logger
  alias BnApis.Helpers.Connection

  def init(opts) do
    opts
  end

  def call(conn, _opts) do
    session_token =
      if Connection.bearer_auth?(conn) do
        Connection.bearer_auth_creds(conn)
      else
        conn |> get_header("session-token")
      end

    x_extended_user_agent = conn |> get_header("x-extended-user-agent")
    Logger.info("session-token: #{session_token}")
    Logger.info("x-extended-user-agent: #{x_extended_user_agent}")
    Logger.info("parameters: #{inspect(conn.params)}")
    conn
  end

  def get_header(conn, header) do
    conn
    |> get_req_header(header)
    |> List.first()
  end
end
