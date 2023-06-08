defmodule Mix.Tasks.AddInvitedUsersRmAssignment do
  use Mix.Task
  import Ecto.Query

  alias BnApis.Repo
  alias BnApis.AssignedBrokers
  alias BnApis.Accounts.{Credential, EmployeeCredential}
  alias BnApis.Accounts.Invite
  alias BnApis.Helpers.Utils

  @shortdoc "Add Employee Assigned Brokers for invited users"
  def run(_) do
    Mix.Task.run("app.start", [])

    stream =
      Invite
      |> join(:inner, [inv], cred in Credential, on: inv.phone_number == cred.phone_number)
      |> join(:left, [inv, cred], ab in AssignedBrokers, on: cred.broker_id == ab.broker_id)
      |> join(:inner, [inv, cred, ab], invitor_cred in Credential, on: inv.invited_by_id == invitor_cred.id)
      |> join(:inner, [inv, cred, ab, invitor_cred], invitor_ab in AssignedBrokers, on: invitor_cred.broker_id == invitor_ab.broker_id)
      |> join(:inner, [inv, cred, ab, invitor_cred, invitor_ab], employee_cred in EmployeeCredential, on: invitor_ab.employees_credentials_id == employee_cred.id)
      |> where([inv, cred, ab, invitor_cred, invitor_ab, employee_cred], is_nil(ab) and employee_cred.active == true)
      |> order_by([inv, cred, ab, invitor_cred, invitor_ab, employee_cred], desc: inv.inserted_at)
      |> distinct([inv, cred, ab, invitor_cred, invitor_ab, employee_cred], [inv.phone_number])
      |> select([inv, cred, ab, invitor_cred, invitor_ab, employee_cred], %{invited_broker_id: cred.broker_id, rm_id: employee_cred.id})
      |> Repo.stream()
      |> Stream.each(fn x -> create_invited_user_assignment(x) end)

    Repo.transaction(fn -> Stream.run(stream) end)
  end

  defp create_invited_user_assignment(params) do
    cron_user_map = Utils.get_employee_user_map(%{"phone_number" => "cron", "country_code" => "+91"})

    AssignedBrokers.changeset(%AssignedBrokers{}, %{
      "active" => true,
      "broker_id" => params[:invited_broker_id],
      "employees_credentials_id" => params[:rm_id],
      "assigned_by_id" => cron_user_map[:user_id]
    })
    |> Repo.insert()
  end
end
