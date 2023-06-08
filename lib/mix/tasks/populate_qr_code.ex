defmodule Mix.Tasks.PopulateQrCode do
  use Mix.Task
  alias BnApis.Repo
  import Ecto.Query
  alias BnApis.Accounts.Credential
  alias BnApis.Organizations.Broker

  @shortdoc "repopulate qr code for brokers"
  def run(_) do
    Mix.Task.run("app.start", [])

    Credential
    |> where([c], c.installed == true)
    |> where([c], not is_nil(c.broker_id))
    |> where([c], not is_nil(c.organization_id))
    |> Repo.all()
    |> Repo.preload([:broker])
    |> Enum.map(&populate_qr_code/1)
  end

  def populate_qr_code(credential) do
    qr_code_url = Broker.upload_qr_code(credential)

    case Broker.changeset(credential.broker, %{"qr_code_url" => qr_code_url}) |> Repo.update() do
      {:ok, broker} ->
        IO.puts("Broker #{broker.name} qr code updated")

      _ ->
        IO.puts("Falied for credential id: #{credential.id}")
    end
  end
end
