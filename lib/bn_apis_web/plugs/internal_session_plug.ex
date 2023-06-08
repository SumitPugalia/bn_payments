defmodule BnApisWeb.Plugs.InternalSessionPlug do
  import Plug.Conn

  def init(opts) do
    opts
  end

  def call(conn, _opts) do
    if is_internal_request?(conn) do
      conn
    else
      conn
      |> send_resp(401, Poison.encode!(%{message: "Only Internal Request are allowed "}))
      |> halt()
    end
  end

  def is_internal_request?(conn) do
    conn.host =~ ".internal."
  end
end
