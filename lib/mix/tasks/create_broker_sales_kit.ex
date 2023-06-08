defmodule Mix.Tasks.CreateBrokerSalesKit do
  use Mix.Task

  alias BnApis.Repo
  import Ecto.Query
  alias BnApis.BrokerKitWorker
  alias BnApis.Organizations.Broker

  @shortdoc "create broker sales kit"
  def run(_) do
    Mix.Task.run("app.start", [])

    Broker
    |> where([b], is_nil(b.portrait_kit_url))
    |> Repo.all()
    |> Enum.map(fn broker ->
      BrokerKitWorker.perform(broker.id)
    end)
  end
end
