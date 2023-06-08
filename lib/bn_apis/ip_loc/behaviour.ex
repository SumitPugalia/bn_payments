defmodule BnApis.IpLoc.Behaviour do
  @typep success_map :: %{
           required(:countryCode) => String.t(),
           required(:city) => String.t(),
           required(:proxy) => boolean()
         }
  @callback get_loc_from_ip(map(), String.t()) :: {:ok, success_map()} | {:error, integer(), map()}
end
