defmodule Mix.Tasks.AddStoryTransactionsRemarks do
  use Mix.Task
  alias BnApis.Repo

  alias BnApis.Rewards.StoryTransaction

  @path "story_transaction_remarks_29_11_22.csv"

  @shortdoc "Add story transaction remarks"
  def run(_) do
    Mix.Task.run("app.start", [])

    update_story_transaction_remarks(@path)
  end

  def update_story_transaction_remarks(path) do
    File.stream!("#{File.cwd!()}/priv/data/#{path}")
    |> CSV.decode(strip_fields: true, headers: true)
    |> Enum.each(fn x -> update_story_transaction(x) end)
  end

  def update_story_transaction({:error, data}) do
    IO.inspect({:error, data})
  end

  def update_story_transaction({:ok, data}) do
    case get_story_transaction(data["story_transaction_id"]) do
      nil ->
        nil

      st ->
        add_remark(st, data)
    end
  end

  defp get_story_transaction(""), do: nil

  defp get_story_transaction(st_id) do
    st_id = String.to_integer(st_id)

    try do
      StoryTransaction
      |> Repo.get(st_id)
    rescue
      error -> IO.inspect(error)
    end
  end

  defp add_remark(st, data) do
    remark = data["remarks"]

    if not is_nil(remark) and remark != "" do
      StoryTransaction.changeset(st, %{"remark" => remark})
      |> Repo.update!()
    end
  end
end
