defmodule Mix.Tasks.RemoveDuplicatePanNumber do
  use Mix.Task
  import Ecto.Query

  alias BnApis.Organizations.Broker
  alias BnApis.Repo
  require Logger

  @shortdoc "Remove duplicate pan number"
  def run(_) do
    Mix.Task.run("app.start", [])
    remove_duplicate_pan_number()
  end

  defp remove_duplicate_pan_number() do
    Repo.transaction(
      fn ->
        Broker
        |> where([b], not is_nil(b.pan))
        |> group_by([b], b.pan)
        |> having([b], count(b.pan) > 1)
        |> select([b], b.pan)
        |> Repo.all()
        |> Enum.each(fn pan ->
          from(b in Broker, where: b.pan == ^pan)
          |> Repo.stream()
          |> Stream.each(fn broker ->
            broker
            |> Broker.update_pan(%{pan: nil}, %{user_id: 0, user_type: "one_timer"})
          end)
          |> Stream.run()
        end)
      end,
      timeout: :infinity
    )
  end
end
