defmodule BnApis.IpLoc.HTTP do
  alias BnApis.Helpers.ExternalApiHelper

  @typep success_map :: %{
           required(:status) => String.t(),
           required(:countryCode) => String.t(),
           required(:city) => String.t(),
           required(:proxy) => boolean()
         }

  @spec get_loc_from_ip(map(), String.t()) :: {:ok, success_map()} | {:error, integer(), map()}
  def get_loc_from_ip(config, ip_string) do
    {status, data} = ExternalApiHelper.perform(:get, config.base_url <> "/" <> ip_string, "", [], params: %{key: config.key, fields: config.fields})

    if status == 200 and data["status"] == "success" do
      {:ok, data}
    else
      {:error, status, data}
    end
  end
end
