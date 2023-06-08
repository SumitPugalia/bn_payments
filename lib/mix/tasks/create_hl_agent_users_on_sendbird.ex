defmodule Mix.Tasks.CreateHlAgentUsersOnSendbird do
  use Mix.Task
  import Ecto.Query

  alias BnApis.Repo
  alias BnApis.Accounts.EmployeeCredential
  alias BnApis.RegisterHlAgentOnSendbird
  alias BnApis.Accounts.EmployeeRole

  @shortdoc "Create HL employee users on sendbird"

  def run(_) do
    Mix.Task.run("app.start", [])
    create_emp_users_on_sendbird()
  end

  def create_emp_users_on_sendbird() do
    EmployeeCredential
    |> where([emp_cred], emp_cred.active == ^true and emp_cred.employee_role_id in [^EmployeeRole.hl_agent().id, ^EmployeeRole.dsa_agent().id])
    |> Repo.all()
    |> Enum.each(fn emp_cred ->
      if is_nil(emp_cred.sendbird_user_id) do
        RegisterHlAgentOnSendbird.perform(EmployeeCredential.get_sendbird_payload_hl(emp_cred))
      end

      Process.sleep(500)
    end)
  end
end
