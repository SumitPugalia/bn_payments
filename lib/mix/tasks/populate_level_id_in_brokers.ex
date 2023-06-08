defmodule Mix.Tasks.PopulateLevelIdInBrokers do
  use Mix.Task
  alias BnApis.Repo
  alias BnApis.Organizations.Broker

  @shortdoc "populate level_id in brokers"
  def run(_) do
    Mix.Task.run("app.start", [])
    populate_level_id_in_brokers()
  end

  def populate_level_id_in_brokers() do
    Broker
    |> Repo.all()
    |> Enum.each(fn broker ->
      broker |> Broker.changeset(%{"level_id" => 1}) |> Repo.update!()
    end)
  end
end
