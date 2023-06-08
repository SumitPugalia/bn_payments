defmodule Mix.Tasks.PopulateCommissionOn do
  import Ecto.Query

  use Mix.Task
  alias BnApis.Repo
  alias BnApis.Homeloan.Bank

  def run(_) do
    Mix.Task.run("app.start", [])

    File.stream!("#{File.cwd!()}/priv/data/bank_commission_on.csv")
    |> CSV.decode()
    |> Enum.to_list()
    |> Enum.map(&populate_commission_on/1)
  end

  def populate_commission_on({:error, data}) do
    IO.inspect("Error: #{data}")
    nil
  end

  def populate_commission_on({:ok, data}) do
    bank_name = data |> Enum.at(0) |> String.trim()
    commission_on = data |> Enum.at(1) |> String.trim()

    Bank
    |> where([b], b.name == ^bank_name and b.active == true)
    |> Repo.all()
    |> Enum.each(fn bank ->
      commission_on = if commission_on == "Sanction", do: "sanctioned_amount", else: "disbursement_amount"
      Bank.changeset(bank, %{"commission_on" => commission_on}) |> Repo.update()
    end)
  end
end
