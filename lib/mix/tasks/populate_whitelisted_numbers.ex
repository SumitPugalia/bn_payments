defmodule Mix.Tasks.PopulateWhitelistedNumbers do
  use Mix.Task
  alias BnApis.Accounts.WhitelistedNumber

  @shortdoc "Whitelist Numbers as Admin"
  def run(_) do
    Mix.Task.run("app.start", [])

    File.stream!("#{File.cwd!()}/priv/data/whitelist.csv")
    |> CSV.decode()
    |> Enum.to_list()
    |> Enum.map(&whitelist_number/1)
  end

  def whitelist_number({:error, data}) do
    IO.inspect("Error: #{data}")
    nil
  end

  def whitelist_number({:ok, [number]}) do
    WhitelistedNumber.create_or_fetch_whitelisted_number(number, "+91")
  end
end
