defmodule Plug.Parsers.XML do
  @behaviour Plug.Parsers
  import Plug.Conn

  def init(opts) do
    opts
  end

  def call(conn, options) do
    conn
    |> read_body(options)
    |> decode()
  end

  defp decode({:ok, body, conn}) do
    case XmlToMap.naive_map(body) do
      parsed when is_map(parsed) ->
        params = Map.put(conn.params, :xml, parsed)
        Map.replace(conn, :params, params)

      error ->
        raise "Malformed XML #{error}"
    end
  rescue
    e -> raise Plug.Parsers.ParseError, exception: e
  end
end
