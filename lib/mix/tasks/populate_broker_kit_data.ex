defmodule Mix.Tasks.PopulateBrokerKitData do
  use Mix.Task
  import Ecto.Query
  alias BnApis.Repo
  alias BnApis.Organizations.Broker
  alias BnApis.BrokerKitWorker

  @shortdoc "populate broker kit data"
  def run(_) do
    Mix.Task.run("app.start", [])
    populate_broker_kit_data()
  end

  def enqueue_broker(broker) do
    IO.puts("BROKER")
    IO.puts("#{broker.id}")

    Exq.enqueue(
      Exq,
      "broker_kit_generator",
      BrokerKitWorker,
      [broker.id]
    )
  end

  def populate_broker_kit_data() do
    Broker
    |> where([c], is_nil(c.portrait_kit_url))
    |> Repo.all()
    |> Enum.each(fn p ->
      p |> enqueue_broker()
    end)
  end
end
