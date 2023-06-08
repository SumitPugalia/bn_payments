defmodule Mix.Tasks.AddHirenDsa do
  import Ecto.Query

  use Mix.Task
  alias BnApis.Repo
  alias BnApis.Organizations.Broker
  alias BnApis.Accounts.Credential
  alias BnApis.AssignedBrokers
  alias BnApis.Accounts.EmployeeCredential
  alias BnApis.Organizations.Organization
  alias BnApisWeb.ChangesetView

  def run(_) do
    Mix.Task.run("app.start", [])

    File.stream!("#{File.cwd!()}/priv/data/hiren_dsas.csv")
    |> CSV.decode()
    |> Enum.to_list()
    |> Enum.with_index()
    |> Enum.map(&create_dsa/1)
  end

  def create_dsa({{:error, data}, _index}) do
    IO.inspect("Error: #{data}")
    nil
  end

  def create_dsa({{:ok, data}, index}) do
    dsa_name = data |> Enum.at(0) |> String.trim()
    dsa_phone_number = data |> Enum.at(2) |> String.trim() |> maybe_split_phone_number()
    pan = data |> Enum.at(3) |> String.trim()
    dsa_email = data |> Enum.at(4) |> String.trim()
    org_name = data |> Enum.at(5) |> String.trim()
    org_address = data |> Enum.at(6) |> String.trim()

    assign_to_emp_code = data |> Enum.at(8) |> String.trim() |> String.replace(" ", "")

    case dsa_name do
      "" ->
        nil

      _dsa_name ->
        # mumbai by default
        city_id = 1
        organization_id = create_organisation(org_name, org_address)

        # chembur by default
        polygon_id = 37

        dsa = Repo.get_by(Credential, phone_number: dsa_phone_number, active: true)

        case dsa do
          nil ->
            IO.inspect("Adding DSA, Count: #{index}, DSA name: #{dsa_name}")

            Repo.transaction(fn ->
              dsa_params = %{
                "name" => dsa_name,
                "role_type_id" => 2,
                "polygon_id" => polygon_id,
                "operating_city" => city_id,
                "pan" => pan,
                "email" => dsa_email,
                # whitelisting of dsa to be set as approved
                "hl_commission_status" => 2
              }

              %Broker{}
              |> Broker.changeset(dsa_params)
              |> Repo.insert()
              |> case do
                {:ok, broker} ->
                  add_employee_assigned_broker(assign_to_emp_code, broker.id, dsa_phone_number)
                  add_entry_in_credentials_table(dsa_phone_number, organization_id, broker.id)

                {:error, error} ->
                  IO.inspect("Broker Insertion failed because:")
                  IO.inspect(error)
                  append_log("#{dsa_phone_number} - #{inspect(ChangesetView.translate_errors(error))}\n")
                  Repo.rollback(error)
              end
            end)

          _dsa ->
            IO.inspect("DSA already registered, Count: #{index}, DSA name: #{dsa_name}")
        end
    end
  end

  def maybe_split_phone_number(phone_number) do
    if String.contains?(phone_number, ","), do: String.split(phone_number, ",") |> Enum.at(0), else: phone_number
  end

  def add_entry_in_credentials_table(dsa_phone_number, organization_id, broker_id) do
    credential_params = %{
      "phone_number" => dsa_phone_number,
      "organization_id" => organization_id,
      "broker_id" => broker_id,
      "profile_type_id" => 1,
      "country_code" => "+91",
      "active" => true
    }

    case %Credential{} |> Credential.changeset(credential_params) |> Repo.insert() do
      {:ok, _} ->
        nil

      {:error, error} ->
        IO.inspect("Credential insertion failed because:")
        append_log("#{dsa_phone_number} - #{inspect(ChangesetView.translate_errors(error))}\n")
        IO.inspect(error)
        Repo.rollback(error)
    end
  end

  def add_employee_assigned_broker(assign_to_emp_code, broker_id, dsa_phone_number) do
    # employee_credentials = Repo.get_by(EmployeeCredential, employee_code: assign_to_emp_code, active: true)
    employee_credentials =
      EmployeeCredential
      |> where([ec], ec.employee_code == ^assign_to_emp_code and ec.active == true)
      |> Repo.all()
      |> List.first()

    case employee_credentials do
      nil ->
        append_log("#{dsa_phone_number} - Employee with employee_code #{assign_to_emp_code} not found\n")
        IO.inspect("Employee with employee_code #{assign_to_emp_code} not found")
        Repo.rollback("Employee with employee_code #{assign_to_emp_code} not found")

      employee_credentials ->
        assigned_broker_params = %{
          "broker_id" => broker_id,
          "employees_credentials_id" => employee_credentials.id,
          "active" => true
        }

        case %AssignedBrokers{} |> AssignedBrokers.changeset(assigned_broker_params) |> Repo.insert() do
          {:ok, _} ->
            nil

          {:error, error} ->
            append_log("#{dsa_phone_number} - #{inspect(ChangesetView.translate_errors(error))}\n")
            IO.inspect("Assigned broker insertion failed because:")
            IO.inspect(error)
            Repo.rollback(error)
        end
    end
  end

  def create_organisation(name, _address) when name in ["NA", "INDIVIDUAL", "Individual", "XXXX", ""], do: 24990

  def create_organisation(name, address) do
    case %Organization{} |> Organization.changeset(%{"name" => name, "firm_address" => address}) |> Repo.insert() do
      {:ok, organisation} -> organisation.id
      # prod -> 24990 # organisation id to be set as 4B
      {:error, _error} -> 24990
    end
  end

  defp append_log(data) do
    {:ok, file} = File.open("log/hiren_dsa_error.log", [:append])
    IO.binwrite(file, data)
    File.close(file)
  end
end
