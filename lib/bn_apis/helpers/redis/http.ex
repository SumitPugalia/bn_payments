defmodule BnApis.Helpers.Redis.HTTP do
  alias BnApis.Helpers.ApplicationHelper
  alias BnApis.Helpers.Redis.Behaviour
  @behaviour Behaviour

  @spec q(list(String.t())) :: {:ok, list(String.t())}
  def q(command) do
    {host, port} = {ApplicationHelper.get_redis_host(), ApplicationHelper.get_redis_port()}
    {:ok, conn} = Redix.start_link(host: host, port: port)
    response = Redix.command(conn, command)
    Redix.stop(conn)
    response
  end
end
