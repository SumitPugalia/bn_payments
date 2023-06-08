defmodule Mix.Tasks.PopulateRoleTypeId do
  use Mix.Task
  import Ecto.Query
  alias BnApis.Repo
  alias BnApis.Organizations.Broker

  @shortdoc "populate role_type_id in brokers"
  def run(_) do
    Mix.Task.run("app.start", [])
    populate_broker_type_id_in_brokers()
  end

  def populate_broker_type_id_in_brokers() do
    IO.puts("STARTED THE TASK - populate role_type_id in brokers")

    Broker
    |> where([b], is_nil(b.role_type_id))
    |> Repo.all()
    |> Enum.each(fn broker ->
      Broker.changeset(broker, %{role_type_id: Broker.real_estate_broker()["id"]}) |> Repo.update!()
    end)

    IO.puts("FINISHED THE TASK - populated role_type_id in brokers")
  end
end
