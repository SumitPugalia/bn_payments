defmodule BnApis.Helpers.WebhookHelper do
  alias BnApis.Repo
  alias BnApis.Helpers.ApplicationHelper
  alias BnApis.Helpers.WebhookHelper
  alias BnApis.Accounts.EmployeeCredential
  alias BnApis.Leads.Schema.LeadDump

  @webhook_bot_employee_phone_number "webhook"

  def get_webhook_bot_employee_credential(), do: Repo.get_by(EmployeeCredential, phone_number: @webhook_bot_employee_phone_number)

  def notify_on_slack(payload) do
    channel = "paytm_webhook_dump"
    payload_message = payload |> Poison.encode!()
    ApplicationHelper.notify_on_slack("Webhook payload - #{payload_message}", channel)
  end

  def handle_lead_webhook(params) do
    WebhookHelper.notify_on_slack(params)
  end

  def handle_lead_propcatalyst_webhook(params) do
    %LeadDump{}
    |> LeadDump.changeset(params)
    |> Repo.insert!()
  end
end
