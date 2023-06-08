defmodule Mix.Tasks.SeedingDataFix do
  use Mix.Task
  alias BnApis.Repo
  import Ecto.Query
  alias BnApis.Accounts.Credential
  alias BnApis.Organizations.Broker

  @shortdoc "Seeding Data Correction"
  def run(_) do
    Mix.Task.run("app.start", [])

    fetch_incorrect_data()
    |> Enum.each(&correct_credentials_data/1)
  end

  def fetch_incorrect_data() do
    # fetches credentials having same broker id
    Credential
    |> where([cred], cred.active == true)
    |> group_by([cred], [cred.broker_id])
    |> having([cred], count(cred.broker_id) > 1)
    |> select([cred], [cred.broker_id, fragment("array_agg(?)", cred.id)])
    |> Repo.all()
  end

  def correct_credentials_data([broker_id, credential_ids]) do
    # keep the first credential
    user_map = %{user_id: 291, user_type: "employee"}
    broker = Repo.get(Broker, broker_id)

    params = %{
      "broker_name" => broker.name
    }

    # update the broker id of the remaining credential
    credential_ids |> tl |> Enum.each(&create_and_update(&1, params, user_map))
  end

  def create_and_update(credential_id, params, user_map) do
    {:ok, broker} = Broker.create_broker(params, user_map)

    Repo.get(Credential, credential_id)
    |> Credential.update_broker_id(broker.id, user_map)
  end
end
