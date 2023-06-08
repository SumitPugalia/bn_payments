defmodule Mix.Tasks.PopulateEmployeeUpi do
  use Mix.Task
  alias BnApis.Accounts.EmployeeAccounts

  @path ["employee_upi.csv"]

  @shortdoc "Populate employee upi"
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
    |> Enum.map(&populate_employee_upi/1)
  end

  def populate_employee_upi({:error, data}) do
    IO.inspect("Error: #{data}")
    nil
  end

  def populate_employee_upi({:ok, data}) do
    phone_number = data |> Enum.at(0)
    upi_id = data |> Enum.at(1)
    user_map = %{user_id: 291, user_type: "employee"}

    with {:ok, _employee_credential} <- EmployeeAccounts.update_upi_id(phone_number, upi_id, user_map) do
      IO.puts("UPI updated for #{phone_number}")
    else
      {_, _error_message} ->
        IO.puts("UPI could not be updated for #{phone_number}")
    end
  end
end
