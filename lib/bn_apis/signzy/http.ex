defmodule BnApis.Signzy.HTTP do
  alias BnApis.Helpers.ExternalApiHelper

  def validate_pan_number(config, item_id, pan, full_name) do
    body = %{
      "service" => "Identity",
      "itemId" => item_id,
      "task" => "verification",
      "accessToken" => config.item_access_token,
      "essentials" => %{
        "number" => pan,
        "name" => full_name,
        "fuzzy" => "true/false"
      }
    }

    ExternalApiHelper.perform(:post, config.base_url <> "/snoops", body, headers(config.access_token))
  end

  def create_identity_object(config, _images \\ []) do
    url = "/patrons/#{config.userId}/identities"

    body = %{
      "type" => "individualPan",
      "email" => config.bn_email_contact,
      "callbackUrl" => config.callback_url,
      "images" => []
    }

    ExternalApiHelper.perform(:post, config.base_url <> url, body, headers(config.access_token))
  end

  def login(config) do
    body = %{
      "username" => config.username,
      "password" => config.password
    }

    ExternalApiHelper.perform(:post, config.base_url <> "/patrons/login", body)
  end

  defp headers(auth_key) do
    [
      {"Content-Type", "application/json"},
      {"Authorization", auth_key}
    ]
  end
end
