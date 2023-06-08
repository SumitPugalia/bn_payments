defmodule Mix.Tasks.DeactivateBrokers do
  use Mix.Task
  alias BnApis.Repo
  alias BnApis.Accounts.Credential
  alias BnApis.Organizations.BillingCompany
  alias BnApis.Helpers.Utils
  alias BnApis.Helpers.AuditedRepo

  @path ["deactivate_brokers_18_11_22.csv"]

  @shortdoc "Deactivate brokers"
  def run(_) do
    Mix.Task.run("app.start", [])

    IO.puts("STARTING DEACTIVATING BROKERS")

    process_data(@path)

    IO.puts("FINISHED DEACTIVATING BROKERS")
  end

  def process_data(path) do
    File.stream!("#{File.cwd!()}/priv/data/#{path}")
    |> CSV.decode(strip_fields: true, headers: true)
    |> Stream.each(fn x -> deactivate_broker(x) end)
    |> Stream.run()
  end

  def deactivate_broker({:error, data}), do: IO.puts("Error in processing data: #{data}")

  def deactivate_broker({:ok, data}) do
    user_map = Utils.get_employee_user_map(%{"phone_number" => "cron", "country_code" => "+91"})
    broker_phone_number = data["Broker Number"]
    cred = Credential.fetch_credential(broker_phone_number, "+91")
    deactivate_broker_with_credential(cred, broker_phone_number, user_map)
  end

  def deactivate_broker_with_credential(nil, phone_number, _user_map), do: IO.puts("Active Credential not found for phone_number: #{phone_number}")

  def deactivate_broker_with_credential(cred, _phone_number, user_map) do
    Repo.transaction(fn ->
      with {:ok, _data} <- Credential.deactivate_changeset(cred) |> AuditedRepo.update(user_map),
           :ok <- BillingCompany.deactivate_brokers_billing_companies(cred.broker_id) do
        :ok
      else
        {:error, reason} ->
          IO.puts("Error in deactivating broker: #{reason}. Phone Number: #{cred.phone_number}")
          Repo.rollback(reason)
      end
    end)
  end
end
