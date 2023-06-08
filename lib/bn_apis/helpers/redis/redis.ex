defmodule BnApis.Helpers.Redis do
  @moduledoc """
  Main service switch for SMS service which decides if we should call API or mock the response.
  """
  alias BnApis.Helpers.Redis.HTTP

  @spec q(list(String.t())) :: {:ok, list(String.t())}
  def q(command) do
    get_module().q(command)
  end

  defp get_module() do
    :bn_apis
    |> Application.get_env(__MODULE__, [])
    |> Keyword.get(:redis_module, HTTP)
  end
end
