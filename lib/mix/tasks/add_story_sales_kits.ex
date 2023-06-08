defmodule Mix.Tasks.AddStorySalesKits do
  use Mix.Task
  import Ecto.Query
  alias BnApis.Repo
  alias BnApis.Stories.{Story, StorySalesKit}
  alias BnApis.Helpers.{Utils, AuditedRepo, ExternalApiHelper}

  @path "story_sales_kits_youtube_urls_04102022.csv"

  @shortdoc "Add youtube urls in story sales kits"
  def run(_) do
    Mix.Task.run("app.start", [])

    process_data(@path)
  end

  def process_data(path) do
    File.stream!("#{File.cwd!()}/priv/data/#{path}")
    |> CSV.decode(strip_fields: true, headers: true)
    |> Enum.each(fn x -> maybe_add_story_sales_kits(x) end)
  end

  def maybe_add_story_sales_kits({:error, reason}), do: IO.inspect({:error, reason})

  def maybe_add_story_sales_kits({:ok, data}) do
    try do
      user_map = Utils.get_employee_user_map(%{"phone_number" => "cron", "country_code" => "+91"})
      youtube_url_exists = youtube_url_exists?(data["Youtube Link"]) and StorySalesKit.validate_youtube_url_format(:youtube_url, data["Youtube Link"]) == []
      story = Story |> where([st], st.uuid == ^data["uuid"]) |> Repo.one()

      if youtube_url_exists and not is_nil(story) do
        sales_kit_params = create_story_sales_kit_params(data, story.id)

        if not is_nil(sales_kit_params) do
          StorySalesKit.changeset(%StorySalesKit{}, sales_kit_params)
          |> AuditedRepo.insert(user_map)
          |> case do
            {:ok, _changeset} -> :ok
            {:error, reason} -> IO.inspect({:error, reason})
          end
        end
      end
    rescue
      err -> IO.inspect(err)
    end
  end

  defp youtube_url_exists?(""), do: false
  defp youtube_url_exists?(nil), do: false
  defp youtube_url_exists?(_url), do: true

  defp create_story_sales_kit_params(data, story_id) do
    video_id = get_youtube_video_id(data["Youtube Link"])
    title = ExternalApiHelper.get_youtube_video_title_by_id(video_id)

    if title != "" do
      %{
        name: title,
        attachment_type_id: 4,
        youtube_url: data["Youtube Link"],
        active: true,
        story_id: story_id
      }
    else
      nil
    end
  end

  defp get_youtube_video_id("http://youtu.be/" <> id), do: id
  defp get_youtube_video_id("http://www.youtube.com/watch?v=" <> id), do: id
  defp get_youtube_video_id("http://www.youtube.com/?v=" <> id), do: id
  defp get_youtube_video_id("https://youtu.be/" <> id), do: id
  defp get_youtube_video_id("https://www.youtube.com/watch?v=" <> id), do: id
  defp get_youtube_video_id("https://www.youtube.com/?v=" <> id), do: id
  defp get_youtube_video_id(_), do: nil
end
