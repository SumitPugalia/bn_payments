defmodule BnApis.WorkerHelper do
  alias BnApis.Repo
  alias BnApis.Accounts.EmployeeCredential

  @cron_bot_employee_phone_number "cron"
  def get_bot_employee_credential(), do: Repo.get_by(EmployeeCredential, phone_number: @cron_bot_employee_phone_number)
end
