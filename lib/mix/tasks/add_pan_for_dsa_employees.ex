defmodule Mix.Tasks.AddPanForDsaEmployees do
  use Mix.Task

  alias BnApis.Accounts.EmployeeCredential
  alias BnApis.Repo

  @path_l1 "duregesh_team_employee_pan.csv"

  @shortdoc "Adding Pan Details for DSA Employees"
  def run(_) do
    Mix.Task.run("app.start", [])
    process_data(@path_l1)
  end

  def process_data(path) do
    File.stream!("#{File.cwd!()}/priv/data/#{path}")
    |> CSV.decode(strip_fields: true, headers: true)
    |> Enum.each(fn x -> add_pan_details(x) end)
  end

  def add_pan_details({:error, data}, _path) do
    IO.inspect({:error, data})
  end

  def add_pan_details({:ok, data}) do
    try do
      case EmployeeCredential |> Repo.get_by(phone_number: data["Phone"]) do
        nil ->
          IO.puts("employee Not found :#{data["Phone"]}")

        employee ->
          ch = employee |> EmployeeCredential.changeset(%{pan: data["PAN Number"]})

          if(ch.valid?) do
            ch |> Repo.update()
            IO.puts("Successfully Added pan for user: #{data["Phone"]}")
          else
            IO.inspect(ch.errors)
          end
      end
    rescue
      err -> IO.inspect(err)
    end
  end
end
