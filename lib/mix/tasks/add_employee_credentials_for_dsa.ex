defmodule Mix.Tasks.AddEmployeeCredentialsForDsa do
  use Mix.Task

  alias BnApis.Accounts.EmployeeCredential
  alias BnApis.Helpers.Utils
  alias BnApis.Accounts.EmployeeRole
  alias BnApis.Repo
  alias BnApis.Places.City

  @path_l1 "emp_data_l1_27012023.csv"
  @path_l2 "emp_data_l2_27012023.csv"
  @path_l3 "emp_data_l3_27012023.csv"

  @shortdoc "Add Employee credential for DSA"
  def run(_) do
    Mix.Task.run("app.start", [])
    process_data(@path_l1)
    process_data(@path_l2)
    process_data(@path_l3)
  end

  def process_data(path) do
    File.stream!("#{File.cwd!()}/priv/data/#{path}")
    |> CSV.decode(strip_fields: true, headers: true)
    |> Enum.each(fn x -> add_employee_credentials(x, path) end)
  end

  def add_employee_credentials({:error, data}, _path) do
    IO.inspect({:error, data})
  end

  def add_employee_credentials({:ok, data}, path) do
    try do
      case EmployeeCredential |> Repo.get_by(phone_number: data["Phone"]) do
        nil ->
          create_employee_credential(data, path)

        _employee ->
          IO.puts("employee already registered in DB phone_number :#{data["Phone"]}")
      end
    rescue
      err -> IO.inspect(err)
    end
  end

  def create_employee_credential(data, _path) do
    user_map = Utils.get_employee_user_map(%{"phone_number" => "cron", "country_code" => "+91"})
    employee_role_id = EmployeeRole.dsa_agent().id

    reporting_manager_id =
      if data["Reporting Manager Phone"] not in [nil, ""] do
        case EmployeeCredential |> Repo.get_by(phone_number: data["Reporting Manager Phone"]) do
          nil -> IO.puts("employee not exist for Employee code : #{data["Reporting Manager"]}")
          emp -> emp.id
        end
      else
        case EmployeeCredential |> Repo.get_by(phone_number: "9819619866") do
          nil -> IO.puts("employee not exist for phone number: 9819619866")
          emp -> emp.id
        end
      end

    create_employee_cred(data["Name"], data["Phone"], employee_role_id, data["Email"], data["Emp Code"], reporting_manager_id, user_map, data["UPI ID"], 1)
  end

  def create_employee_cred(name, phone_number, employee_role_id, email, employee_code, reporting_manager_id, user_map, upi_id, city_id \\ 1) do
    city_id =
      case Repo.get_by(City, id: city_id) do
        nil -> 1
        _city -> city_id
      end

    params = %{
      "name" => name,
      "phone_number" => phone_number,
      "country_code" => "+91",
      "employee_role_id" => employee_role_id,
      "email" => email,
      "employee_code" => employee_code,
      "city_id" => city_id,
      "reporting_manager_id" => reporting_manager_id,
      "access_city_ids" => [city_id],
      "upi_id" => upi_id,
      "vertical_id" => 5
    }

    case EmployeeCredential.signup_user(params, user_map) do
      {:ok, _employee_credential} ->
        IO.puts("user successfully registered phone_number: #{phone_number}")

      {:error, changset} ->
        IO.inspect(changset)
    end
  end
end
