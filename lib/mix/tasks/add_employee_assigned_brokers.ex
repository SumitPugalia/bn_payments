defmodule Mix.Tasks.AddEmployeeAssignedBrokers do
  use Mix.Task

  alias BnApis.AssignedBrokers
  alias BnApis.Accounts.{Credential, EmployeeCredential}
  alias BnApis.Helpers.Utils

  @path "employee_assigned_brokers_07102022.csv"

  @shortdoc "Add Employee Assigned Brokers"
  def run(_) do
    Mix.Task.run("app.start", [])

    process_data(@path)
  end

  def process_data(path) do
    File.stream!("#{File.cwd!()}/priv/data/#{path}")
    |> CSV.decode(strip_fields: true, headers: true)
    |> Enum.each(fn x -> add_employee_assigned_brokers(x) end)
  end

  def add_employee_assigned_brokers({:error, data}) do
    IO.inspect({:error, data})
  end

  def add_employee_assigned_brokers({:ok, data}) do
    user_map = Utils.get_employee_user_map(%{"phone_number" => "cron", "country_code" => "+91"})

    try do
      cred = Credential.fetch_credential(data["Broker Number"], "+91")
      employee = EmployeeCredential.fetch_employee_credential(data["Employee Number"], "+91")

      case {cred, employee} do
        {nil, nil} ->
          IO.puts("Received nil for Broker Number: #{data["Broker Number"]} and nil for Employee Number: #{data["Employee Number"]}")

        {nil, _} ->
          IO.puts("Received nil for Broker Number: #{data["Broker Number"]}")

        {_, nil} ->
          IO.puts("Received nil for Employee Number: #{data["Employee Number"]}")

        {_cred, _employee} ->
          AssignedBrokers.remove_all_assignments(cred.broker_id)
          AssignedBrokers.create_assignment(user_map[:user_id], employee.id, cred.broker_id)
      end
    rescue
      err -> IO.inspect(err)
    end
  end
end
