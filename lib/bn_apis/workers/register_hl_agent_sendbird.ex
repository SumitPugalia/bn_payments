defmodule BnApis.RegisterHlAgentOnSendbird do
  import Ecto.Query
  alias BnApis.Helpers.ExternalApiHelper
  alias BnApis.Helpers.ApplicationHelper
  alias BnApis.Accounts.EmployeeCredential
  alias BnApis.Repo
  alias BnApis.Accounts.EmployeeRole

  def perform(payload) do
    try do
      sendbird_user = ExternalApiHelper.get_user_on_sendbird(payload["user_id"])
      emp_cred = Repo.get_by(EmployeeCredential, uuid: payload["user_id"])

      case sendbird_user do
        {:ok, response} ->
          emp_cred |> EmployeeCredential.changeset(%{"sendbird_user_id" => response["user_id"]}) |> Repo.update!()

        {:error, _msg} ->
          sendbird_user_id = ExternalApiHelper.create_user_on_sendbird(payload)

          if not is_nil(sendbird_user_id) do
            emp_cred |> EmployeeCredential.changeset(%{"sendbird_user_id" => sendbird_user_id}) |> Repo.update!()
          end
      end
    rescue
      err ->
        channel = ApplicationHelper.get_slack_channel()

        ApplicationHelper.notify_on_slack(
          "Error in registering a user on sendbird for uuid: #{payload["user_id"]}......#{Exception.message(err)}",
          channel
        )
    end
  end

  # cron function to register user which were not registered successfully, runs every hour
  def perform_cron() do
    EmployeeCredential
    |> where(
      [emp_cred],
      emp_cred.active == true and emp_cred.employee_role_id in [^EmployeeRole.hl_agent().id, ^EmployeeRole.dsa_agent().id] and
        is_nil(emp_cred.sendbird_user_id)
    )
    |> Repo.all()
    |> Enum.each(fn emp_cred ->
      if emp_cred.employee_role_id == EmployeeRole.hl_agent().id do
        perform(EmployeeCredential.get_sendbird_payload_hl(emp_cred))
      else
        perform(EmployeeCredential.get_sendbird_payload_dsa_agent(emp_cred))
      end
    end)
  end
end
