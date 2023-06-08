defmodule BnApis.Helpers.SlashHelper do
  alias BnApis.Helpers.ApplicationHelper
  alias BnApis.Helpers.ExternalApiHelper

  @expired_posts "expired_posts"
  @reported_posts "reported_posts"

  def expired_posts(), do: @expired_posts
  def reported_posts(), do: @reported_posts

  def push_lead(leadId, leadType, tokenId, customerNumber) do
    token = get_auth_token()
    create_lead(customerNumber, tokenId, leadId, leadType, token)
  end

  def create_lead(customerNumber, tokenId, leadId, leadType, authToken) do
    url = ApplicationHelper.get_slash_url() <> "slashRtc/cloudAuth/private/authApis"

    payload = %{
      "apiName" => "setLeadDetailInProcessToken",
      "customerNumber" => customerNumber,
      "tokenId" => tokenId,
      "raw_lead" => leadId,
      "type" => leadType
    }

    headers = [{"Authorization", "Bearer #{authToken}"}]
    headers = headers ++ [{"Content-Type", "application/json"}]

    {_status, response} =
      ExternalApiHelper.perform(
        :post,
        url,
        payload,
        headers,
        recv_timeout: 500_000
      )

    response
  end

  def get_auth_token() do
    url = ApplicationHelper.get_slash_url() <> "slashRtc/cloudAuth/api/login"
    username = ApplicationHelper.get_slash_username()
    password = ApplicationHelper.get_slash_password()

    payload = %{
      "username" => username,
      "password" => password
    }

    headers = [{"Content-Type", "application/json"}]

    {_status, response} =
      ExternalApiHelper.perform(
        :post,
        url,
        payload,
        headers,
        recv_timeout: 500_000
      )

    response["token"]
  end

  def get_campaign_token_id(city, source) do
    city = city && city |> String.downcase()
    source = source && source |> String.downcase()
    env = ApplicationHelper.get_server_env()

    cond do
      env == "production" ->
        cond do
          source == "offline" ->
            "fde778f585179fa8b68891c8c0c47170"

          source == @expired_posts ->
            "ff95fd3460a713a0eb2efa4bf54d1f10"

          source == @reported_posts ->
            "cd8dffc940628e9d8125d86c730fe3c2"

          source == "affiliates" ->
            "263b077e0b7719a3f2ae0e37f25445f7"

          city == "mumbai" and source == "aggregator" ->
            "bce2635356a679a39f907247c86d2ac2"

          city == "pune" and source == "aggregator" ->
            "6fba5af4d39495c9aaaa362cd66290f4"

          (city == "bengaluru" or city == "bangalore") and source == "aggregator" ->
            "25ea686ecfd0c0662899929b1f4de76f"

          (city == "gurugram" or city == "gurgaon") and source == "aggregator" ->
            "2e01422a8d4e93f7db2c377c24418e41"

          city == "mumbai" ->
            "eeb1ffe4d11bd7e3ab207b3fb11849af"

          city == "pune" ->
            "8b425762332f6512d1cc7c1c269be931"

          city == "bengaluru" or city == "bangalore" ->
            "4e493f3c6b956237324b979d776bbab8"

          city == "gurugram" or city == "gurgaon" ->
            "2ba9a9d7a201ffd145f02bfd1284677a"

          true ->
            "eeb1ffe4d11bd7e3ab207b3fb11849af"
        end

      true ->
        "2a753f96e13fe9c29449031e77f87191"
    end
  end

  def async_push_to_slash(lead_details, user_map \\ %{}) do
    token_id = get_campaign_token_id(lead_details["city"], lead_details["source"])
    Exq.enqueue(Exq, "slash_lead_push", BnApis.RawPosts.PushSlashLeadWorker, [lead_details, token_id, user_map])
  end
end
