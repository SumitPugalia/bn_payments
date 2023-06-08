defmodule BnApis.Signzy.API do
  alias BnApis.Signzy.HTTP

  def new do
    config = Application.get_env(:bn_apis, __MODULE__, [])

    %{
      base_url: Keyword.fetch!(config, :signzy_base_url),
      username: Keyword.fetch!(config, :signzy_username),
      password: Keyword.fetch!(config, :signzy_password),
      callback_url: Keyword.fetch!(config, :signzy_callback_url),
      bn_email_contact: Keyword.fetch!(config, :signzy_bn_email_contact)
    }
  end

  def validate_pan_details(pan, pan_image_url, full_name) do
    config = new()

    case get_module().login(config) do
      {200, data} ->
        config = Map.put(config, :access_token, data["id"]) |> Map.put(:userId, data["userId"])

        case get_module().create_identity_object(config, [pan_image_url]) do
          {200, data} ->
            config = Map.put(config, :item_access_token, data["accessToken"])

            case get_module().validate_pan_number(config, data["id"], pan, full_name) do
              {200, response_data} ->
                parse_response_data(response_data)

              {_, error} ->
                {:error, "Issue while validating PAN: #{inspect(error)}"}
            end

          {_, error} ->
            {:error, "Issue while creating the Signzy identity object: #{inspect(error)}"}
        end

      {_, error} ->
        {:error, "Issue while authenticating to Signzy: #{inspect(error)}"}
    end
  end

  ## Private APIs

  defp parse_response_data(nil), do: {:ok, false}

  defp parse_response_data(_response_data = %{"response" => %{"result" => result}}) do
    valid_pan? = Map.get(result, "verified", false)
    pan_name = Map.get(result, "upstreamName", nil)
    {:ok, valid_pan?, pan_name}
  end

  defp parse_response_data(_response_data), do: {:ok, false}

  defp get_module do
    :bn_apis
    |> Application.get_env(__MODULE__, [])
    |> Keyword.get(:module_name, HTTP)
  end
end
