defmodule BnApis.IpLoc.API do
  alias BnApis.IpLoc.HTTP

  @typep success_map :: %{
           required(:countryCode) => String.t(),
           required(:city) => String.t(),
           required(:proxy) => boolean()
         }

  def new do
    config = Application.get_env(:bn_apis, __MODULE__, [])

    %{
      base_url: Keyword.fetch!(config, :base_url),
      key: Keyword.fetch!(config, :key),
      fields: Keyword.fetch!(config, :fields)
    }
  end

  @spec get_loc_from_ip(map(), String.t()) :: {:ok, success_map()} | {:error, integer(), map()}
  def get_loc_from_ip(config, ip_string), do: get_module().get_loc_from_ip(config, ip_string)

  defp get_module do
    :bn_apis
    |> Application.get_env(__MODULE__, [])
    |> Keyword.get(:module_name, HTTP)
  end
end
