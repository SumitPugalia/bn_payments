defmodule BnApis.SendHomeloanSmsWorker do
  alias BnApis.Organizations.Broker
  alias BnApis.Homeloan.Lead
  alias BnApis.Helpers.{SmsService, ApplicationHelper}
  alias BnApis.Repo

  require Logger

  def perform(id) do
    homeloan_lead = Repo.get_by(Lead, id: id)
    homeloan_lead = homeloan_lead |> Repo.preload(:country)
    broker = Broker.fetch_broker_from_id(homeloan_lead.broker_id)

    link = ApplicationHelper.hosted_domain_url() <> "/hl/#{homeloan_lead.external_link}"

    link_to_send =
      case Bitly.Link.shorten(link) do
        %Bitly.Link{data: %{url: bitly_url}, status_code: 200} ->
          bitly_url

        _ ->
          link
      end

    message = get_sms_data(homeloan_lead, broker, link_to_send)

    with {:ok, phone} <-
           ExPhoneNumber.parse(
             homeloan_lead.phone_number,
             homeloan_lead.country.url_name
           ),
         phone_number = phone.national_number |> Integer.to_string() do
      number =
        if ApplicationHelper.get_should_send_sms() == "true",
          do: phone_number,
          else: ApplicationHelper.get_default_sms_number()

      SmsService.send_sms(number, message, false)
    else
      {:error, _} ->
        Logger.error("Could not send sms for lead #{homeloan_lead.id}")
    end
  end

  def get_sms_data(homeloan_lead, broker, link) do
    "Hi #{homeloan_lead.name},\nThank you for showing interest in HomeLoanExpert. We have received your request to initiate home loan process through Channel Partner #{broker.name}. To Confirm kindly click on link #{link}"
  end
end
