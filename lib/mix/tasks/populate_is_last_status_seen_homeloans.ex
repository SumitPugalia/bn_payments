defmodule Mix.Tasks.PopulateIsLastStatusSeenHomeloans do
  use Mix.Task
  alias BnApis.Repo
  alias BnApis.Homeloan.Lead

  @shortdoc "populate is_last_status_seen in homeloan leads"
  def run(_) do
    Mix.Task.run("app.start", [])
    populate_is_last_status_is_seen_in_notification_req()
  end

  def populate_is_last_status_is_seen_in_notification_req() do
    Repo.transaction(
      fn ->
        Lead
        |> Repo.stream()
        |> Stream.each(fn lead -> lead |> Lead.changeset(%{"is_last_status_seen" => true}) |> Repo.update!() end)
        |> Stream.run()
      end,
      timeout: :infinity
    )
  end
end
