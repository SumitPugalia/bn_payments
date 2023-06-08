defmodule Mix.Tasks.UploadReraIdsInStories do
  use Mix.Task
  alias BnApis.Repo

  alias BnApis.Stories.Story

  @path "stories_rera_ids.csv"

  @shortdoc "Add RERA IDs in Stories"
  def run(_) do
    Mix.Task.run("app.start", [])

    read_data_from_csv(@path)
  end

  def read_data_from_csv(path) do
    File.stream!("#{File.cwd!()}/priv/data/#{path}")
    |> CSV.decode(strip_fields: true, headers: true)
    |> Enum.each(fn x -> update_rera_id(x) end)
  end

  def update_rera_id({:error, data}) do
    IO.inspect({:error, data})
  end

  def update_rera_id({:ok, data}) do
    case get_story_data(data["Story Id"]) do
      nil ->
        nil

      st ->
        add_rera_id(st.rera_ids, st, data["RERA Number"])
    end
  end

  defp get_story_data(""), do: nil

  defp get_story_data(st_id) do
    st_id = String.to_integer(st_id)

    Story |> Repo.get(st_id) |> Repo.preload([:story_sales_kits, :story_sections])
  end

  defp add_rera_id(_st_rera_ids, _st, ""), do: :ok

  defp add_rera_id(nil, st, rera_id) do
    Story.changeset(st, %{"rera_ids" => [rera_id]})
    |> Repo.update!()
  end

  defp add_rera_id(st_rera_ids, st, rera_id) do
    case create_rera_array(st_rera_ids, rera_id) do
      nil ->
        :ok

      rera_ids ->
        Story.changeset(st, %{"rera_ids" => rera_ids})
        |> Repo.update!()
    end
  end

  defp create_rera_array(st_rera_ids, rera_id) do
    case Enum.find(st_rera_ids, fn x -> x == rera_id end) do
      nil -> Enum.concat(st_rera_ids, [rera_id])
      _rera_id -> nil
    end
  end
end
