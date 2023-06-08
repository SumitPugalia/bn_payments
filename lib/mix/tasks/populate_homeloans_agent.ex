defmodule Mix.Tasks.PopulateHomeloansAgent do
  use Mix.Task
  import Ecto.Query

  alias BnApis.Repo
  alias BnApis.Accounts.EmployeeCredential
  alias BnApis.Homeloan.Lead

  @path [
    "homeloans/assignment/afreen.csv",
    "homeloans/assignment/harshada.csv",
    "homeloans/assignment/jayshree.csv",
    "homeloans/assignment/nilakshi.csv",
    "homeloans/assignment/pooja.csv",
    "homeloans/assignment/shraddha.csv",
    "homeloans/assignment/sneha.csv",
    "homeloans/assignment/suman.csv"
  ]

  @shortdoc "Populate homeloans agent"
  def run(_) do
    Mix.Task.run("app.start", [])
    # remove first line from csv file that contains headers
    @path
    |> Enum.each(&populate/1)
  end

  def populate(path) do
    File.stream!("#{File.cwd!()}/priv/data/#{path}")
    |> CSV.decode()
    |> Enum.to_list()
    |> Enum.map(&populate_homeloans_agent/1)
  end

  def populate_homeloans_agent({:error, data}) do
    IO.inspect("Error: #{data}")
    nil
  end

  def populate_homeloans_agent({:ok, data}) do
    client_phone_number = data |> Enum.at(0)
    agent_phone_number = data |> Enum.at(1)

    employee_credential =
      EmployeeCredential
      |> where([cred], cred.phone_number == ^agent_phone_number)
      |> where([cred], cred.active == true and cred.hl_lead_allowed == true)
      |> Repo.one()

    if is_nil(employee_credential) do
      IO.puts("Agent #{agent_phone_number} with relevant access does not exist")
    else
      leads =
        Lead
        |> where([l], l.phone_number == ^client_phone_number)
        |> Repo.all()

      if length(leads) > 0 do
        # leads |> Enum.map(fn lead ->
        #   Lead.transfer_lead(lead.id, employee_credential.id)
        # end)
        IO.puts("Client #{client_phone_number} is assigned to Agent #{agent_phone_number}")
      else
        IO.puts("Client #{client_phone_number} does not have any leads")
      end
    end
  end
end
