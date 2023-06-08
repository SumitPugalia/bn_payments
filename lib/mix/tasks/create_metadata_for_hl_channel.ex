defmodule Mix.Tasks.CreateMetadataForHlChannel do
  use Mix.Task

  alias BnApis.Repo
  alias BnApis.Homeloan.Lead
  import Ecto.Query
  alias BnApis.Helpers.ExternalApiHelper

  @shortdoc "Create metadata for homeloan channel on sendbird"

  def run(_) do
    Mix.Task.run("app.start", [])
    create_metadata_for_hl_channel()
  end

  defp create_metadata_for_hl_channel() do
    Lead
    |> where([l], not is_nil(l.channel_url))
    |> Repo.all()
    |> Enum.each(fn lead ->
      meta_data = %{
        "metadata" => %{
          "call_through" => "s2c",
          "lead_id" => "#{lead.id}",
          "call_with" => "hl_agent"
        },
        "include_ts" => true
      }

      IO.inspect("*** Creating metadata for channel_url: #{lead.channel_url} ***")
      ExternalApiHelper.create_sendbird_channel_meta_data(meta_data, lead.channel_url)
    end)
  end
end
