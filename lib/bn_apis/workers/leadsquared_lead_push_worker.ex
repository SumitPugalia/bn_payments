defmodule BnApis.LeadsquaredLeadPushWorker do
  alias BnApis.Repo
  alias BnApis.Organizations.Broker
  alias BnApis.Helpers.ApplicationHelper
  alias BnApis.Homeloan.Lead
  alias BnApis.Homeloan.Status
  alias BnApis.Helpers.ExternalApiHelper

  def perform(lead_id) do
    lead = Repo.get_by(Lead, id: lead_id)

    if not is_nil(lead) do
      payload = get_leadsquared_payload(lead)

      try do
        {status_code, response} = ExternalApiHelper.push_hl_lead_to_leadsquared(payload)

        if status_code == 200 do
          lead_squared_uuid = response["Message"]["Id"]
          update_lead_squared_uuid(lead, lead_squared_uuid)
        else
          exceptionMessage = response["ExceptionMessage"]
          send_on_slack("leadsquared push failed for lead id - #{lead_id}, with message #{exceptionMessage}")
        end
      rescue
        _ -> send_on_slack("Failed to push to leadsquared for lead id - #{lead_id}")
      end
    end
  end

  def update_lead_squared_uuid(lead, lead_squared_uuid) do
    ch = Lead.changeset(lead, %{lead_squared_uuid: lead_squared_uuid})
    Repo.update!(ch)
  end

  def send_on_slack(text) do
    channel = ApplicationHelper.get_slack_channel()

    text
    |> ApplicationHelper.notify_on_slack(channel)
  end

  def get_leadsquared_payload(lead) do
    lead = lead |> Repo.preload([:broker, :latest_lead_status])
    broker = lead.broker
    broker_credential = Broker.get_credential_data(broker)
    payload = []

    country_name =
      if lead.country_id == 1 do
        "India"
      else
        nil
      end

    broker_name = broker.name
    broker_phone = broker_credential["phone_number"]
    lead_status = Status.status_list()[lead.latest_lead_status.status_id]
    lead_status_name = lead_status["display_name"]

    inserted_at_date =
      lead.inserted_at
      |> Timex.Timezone.convert("Asia/Kolkata")
      |> Timex.format!("%l:%M %P, %d %b, %Y", :strftime)

    # todo: do we need to push owner email address?
    payload =
      payload ++
        [
          %{
            "Attribute" => "mx_Name",
            "Value" => lead.name
          },
          %{
            "Attribute" => "FirstName",
            "Value" => lead.name
          },
          %{
            "Attribute" => "Phone",
            "Value" => lead.phone_number
          },
          %{
            "Attribute" => "mx_Country",
            "Value" => country_name
          },
          %{
            "Attribute" => "Mobile",
            "Value" => broker_phone
          },
          %{
            "Attribute" => "mx_Name_of_broker",
            "Value" => broker_name
          },
          %{
            "Attribute" => "mx_External_link",
            "Value" => lead.external_link
          },
          %{
            "Attribute" => "mx_inserted_at",
            "Value" => inserted_at_date
          },
          %{
            "Attribute" => "ProspectStage",
            "Value" => lead_status_name
          }
        ]

    payload
  end
end
