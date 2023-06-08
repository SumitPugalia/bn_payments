defmodule Mix.Tasks.UpdateChannelNameForCommercial do
  use Mix.Task
  import Ecto.Query
  alias BnApis.Repo
  alias BnApis.Commercials.CommercialChannelUrlMapping
  alias BnApis.Helpers.ExternalApiHelper

  @shortdoc "Correct channel name for commercial channels"
  def run(_) do
    Mix.Task.run("app.start", [])
    update_channel_name()
  end

  def update_channel_name() do
    CommercialChannelUrlMapping
    |> where([c], not is_nil(c.channel_url))
    |> Repo.all()
    |> Enum.each(fn channel ->
      payload = get_update_payload(channel)
      ExternalApiHelper.update_sendbird_channel(channel.channel_url, payload)
    end)
  end

  defp get_update_payload(channel) do
    channel = channel |> Repo.preload([:commercial_property_post])
    post = channel.commercial_property_post |> Repo.preload([:building, building: [:polygon]])

    property_type =
      if not is_nil(post.is_available_for_lease) and not is_nil(post.is_available_for_purchase) and
           post.is_available_for_lease and post.is_available_for_purchase do
        "purchase & lease"
      else
        if not is_nil(post.is_available_for_lease) and post.is_available_for_lease, do: "lease", else: "purchase"
      end

    %{
      "name" => "Grade #{post.building.grade}, #{post.building.polygon.name}, #{property_type} - ##{post.id}"
    }
  end
end
