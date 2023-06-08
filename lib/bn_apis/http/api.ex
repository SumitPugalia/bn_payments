defmodule BnApis.HTTP do
  @module :bn_apis
          |> Application.get_env(__MODULE__, [])
          |> Keyword.get(:module_name, HTTPoison)

  defdelegate post(url, body, headers), to: @module
  defdelegate request(request_type, url, body_params, headers, options), to: @module
  defdelegate get(url, headers), to: @module
end
