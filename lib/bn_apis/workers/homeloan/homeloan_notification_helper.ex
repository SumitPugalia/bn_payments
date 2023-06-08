defmodule BnApis.Homeloan.HomeloanNotificationHelper do
  import Ecto.Query
  alias BnApis.Homeloan.Lead
  alias BnApis.Repo
  alias BnApis.Helpers.FcmNotification
  alias BnApis.Accounts.Credential

  def perform(id, message) do
    homeloan_lead = Repo.get_by(Lead, id: id)
    credential = Credential.get_credential_from_broker_id(homeloan_lead.broker_id)
    type = "HOME_LOAN_UPDATE"
    notification_data = get_notification_data(message, homeloan_lead.id)

    if not is_nil(notification_data) do
      FcmNotification.send_push(
        credential.fcm_id,
        %{data: notification_data, type: type},
        credential.id,
        credential.notification_platform
      )
    else
      nil
    end
  end

  def get_notification_data(message, lead_id) do
    %{
      "title" => "Home Loan Update",
      "message" => message,
      "client_uuid" => lead_id
    }
  end
end
