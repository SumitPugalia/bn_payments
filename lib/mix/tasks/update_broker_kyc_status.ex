defmodule Mix.Tasks.UpdateBrokerKycStatus do
  use Mix.Task

  alias BnApis.Organizations.Broker
  alias BnApis.Helpers.Utils

  @broker_ids [
    82101,
    143_831,
    131_077,
    143_839,
    49658,
    51272,
    143_831,
    143_430,
    41307,
    7102,
    128_124,
    46781,
    29443,
    24287,
    141_037,
    47092,
    20589,
    114_223,
    51576,
    15698,
    131_997,
    143_328,
    143_832,
    85792,
    40404,
    51944,
    140_734,
    121_914,
    81822,
    143_220,
    119_060,
    141_032,
    129_746
  ]

  @shortdoc "Update kyc status for brokers"
  def run(_) do
    Mix.Task.run("app.start", [])

    IO.puts("STARTING TO UPDATE KYC STATUS")

    @broker_ids
    |> Enum.each(&update_broker_kyc_status/1)

    IO.puts("UPDATE TASK COMPLETE")
  end

  defp update_broker_kyc_status(broker_id) do
    user_map = Utils.get_employee_user_map(%{"phone_number" => "cron", "country_code" => "+91"})

    kyc_changes = %{
      kyc_status: :approved,
      is_pan_verified: true
    }

    Broker.fetch_broker_from_id(broker_id)
    |> case do
      nil ->
        IO.inspect("============== Not Found:  =============")
        IO.inspect("Broker with id: #{broker_id} not found.")

      broker ->
        Broker.update_kyc_status(broker, kyc_changes, user_map)
        |> case do
          {:ok, _broker} ->
            nil

          {:error, changeset} ->
            IO.inspect("============== Error:  =============")
            IO.inspect("Error while updating broker with id: #{broker_id}.")
            IO.inspect(changeset.errors)
        end
    end
  end
end
