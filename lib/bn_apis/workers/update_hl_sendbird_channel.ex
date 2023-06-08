defmodule BnApis.UpdateHLSendbirdChannel do
  alias BnApis.Helpers.ExternalApiHelper
  alias BnApis.Accounts.EmployeeCredential
  alias BnApis.Repo

  def perform(lead_id, new_employee_id, old_employee_id) do
    # remove old employee from channel
    old_empl_credentials = Repo.get_by(EmployeeCredential, id: old_employee_id)
    payload = %{"user_ids" => [old_empl_credentials.uuid]}
    channel_url = "hl_#{lead_id}"
    ExternalApiHelper.remove_user_from_channel(payload, channel_url)

    # add new employee to channel
    new_empl_credentials = Repo.get_by(EmployeeCredential, id: new_employee_id)
    payload = %{"user_ids" => [new_empl_credentials.uuid]}
    channel_url = "hl_#{lead_id}"
    ExternalApiHelper.add_user_to_channel(payload, channel_url)
  end
end
