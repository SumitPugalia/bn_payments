defmodule Mix.Tasks.AddDsaEmployeesAsDsa do
  import Ecto.Query

  use Mix.Task
  alias BnApis.Repo
  alias BnApis.Organizations.Broker
  alias BnApis.Accounts.Credential
  alias BnApis.AssignedBrokers
  alias BnApis.Accounts.EmployeeCredential
  alias BnApisWeb.ChangesetView

  def run(_) do
    Mix.Task.run("app.start", [])

    add_dsa_employees_as_dsa()
  end

  defp add_dsa_employees_as_dsa() do
    EmployeeCredential
    # dsa agent, dsa admin and dsa super
    |> where([ec], ec.active == ^true and ec.employee_role_id in [29, 30, 31] and not is_nil(ec.pan))
    |> Repo.all()
    |> Enum.each(fn employee ->
      add_dsa_employees(employee)
    end)
  end

  def add_dsa_employees(employee) do
    dsa = Repo.get_by(Credential, phone_number: employee.phone_number, active: true)

    case dsa do
      nil ->
        IO.inspect("Adding DSA, DSA name: #{employee.name}")

        Repo.transaction(fn ->
          dsa_params = %{
            "name" => employee.name,
            "role_type_id" => 2,
            "operating_city" => employee.city_id,
            "pan" => employee.pan,
            "email" => employee.email,
            "hl_commission_status" => 2,
            "is_employee" => true
          }

          %Broker{}
          |> Broker.changeset(dsa_params)
          |> Repo.insert()
          |> case do
            {:ok, broker} ->
              add_employee_assigned_broker(employee.id, broker.id, employee.phone_number)
              add_entry_in_credentials_table(employee.phone_number, nil, broker.id)

            {:error, error} ->
              IO.inspect("Broker Insertion failed because:")
              IO.inspect(error)
              append_log("#{employee.phone_number} - #{inspect(ChangesetView.translate_errors(error))}\n")
              Repo.rollback(error)
          end
        end)

      _dsa ->
        IO.inspect("DSA already registered, DSA name: #{employee.name}")
    end
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

  def add_employee_assigned_broker(employee_id, broker_id, dsa_phone_number) do
    assigned_broker_params = %{
      "broker_id" => broker_id,
      "employees_credentials_id" => employee_id,
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

  defp append_log(data) do
    {:ok, file} = File.open("log/add_dsa_employees_as_dsa_error.log", [:append])
    IO.binwrite(file, data)
    File.close(file)
  end
end
