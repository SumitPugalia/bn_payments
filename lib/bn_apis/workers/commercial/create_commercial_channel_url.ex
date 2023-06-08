defmodule BnApis.Commercial.CreateCommercialChannelUrl do
  alias BnApis.Helpers.ExternalApiHelper
  alias BnApis.Commercials.CommercialChannelUrlMapping
  alias BnApis.Helpers.ApplicationHelper

  @max_retries 5

  def perform(_, _, _, _retry = 0), do: :ignore

  def perform(payload, broker_id, commercial_post_id, retry) do
    channel_response = ExternalApiHelper.create_sendbird_channel(payload)
    channel = ApplicationHelper.get_slack_channel()

    case channel_response do
      nil ->
        retry_count = @max_retries - retry + 1

        ApplicationHelper.notify_on_slack(
          "Channel creation for commercial failed for user_id:#{payload["user_id"]} ,retry_count:#{retry_count}",
          channel
        )

        Exq.enqueue_in(Exq, "commercial_sendbird", retry_count * 10, BnApis.Commercial.CreateCommercialChannelUrl, [
          payload,
          broker_id,
          commercial_post_id,
          retry - 1
        ])

      _ ->
        CommercialChannelUrlMapping.insert(%{
          "broker_id" => broker_id,
          "commercial_property_post_id" => commercial_post_id,
          "channel_url" => channel_response,
          "is_active" => true
        })
    end
  end
end
