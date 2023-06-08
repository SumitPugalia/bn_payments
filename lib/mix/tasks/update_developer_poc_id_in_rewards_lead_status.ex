defmodule Mix.Tasks.UpdateDeveloperPocIdInRewardsLeadStatus do
  use Mix.Task
  alias BnApis.Rewards.{RewardsLeadStatus, Status}
  alias BnApis.Helpers.Utils
  alias BnApis.Accounts.DeveloperPocCredential
  alias BnApis.Repo
  import Ecto.Query

  @shortdoc "Set Developer Poc ID in Auto Approved SV Rewards"

  def run(_) do
    Mix.Task.run("app.start", [])

    IO.inspect("Starting update bn_approver dev poc id")

    update_developer_poc_credential_id()

    IO.inspect("Completed update bn_approver dev poc id")
  end

  def update_developer_poc_credential_id() do
    cron_user = Utils.get_employee_user_map(%{"phone_number" => "cron", "country_code" => "+91"})

    stream =
      RewardsLeadStatus
      |> where([rls], rls.inserted_at >= ^get_26_sept_2022_date() and rls.status_id == ^Status.get_status_id("approved") and rls.employee_credential_id == ^cron_user[:user_id])
      |> Repo.stream()
      |> Stream.each(fn lead_status -> update_bn_approver_id(lead_status) end)

    Repo.transaction(fn -> Stream.run(stream) end)
  end

  def get_26_sept_2022_date() do
    ~N[2022-09-26 00:00:00]
  end

  def update_bn_approver_id(lead_status) do
    bn_approver = DeveloperPocCredential.fetch_bn_approver_credential()

    case RewardsLeadStatus.developer_poc_status_changeset(lead_status, %{"employee_credential_id" => nil, "developer_poc_credential_id" => bn_approver.id}) |> Repo.update() do
      {:ok, _lead_status} -> :ok
      {:error, reason} -> IO.inspect({:error, reason})
    end
  end
end
