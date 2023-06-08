defmodule BnApis.SendCabNotificationWorker do
  alias BnApis.Helpers.FcmNotification
  alias BnApis.Accounts.Credential
  alias BnApis.Cabs.BookingRequest
  alias BnApis.Repo

  def perform(id, identifier) do
    booking_request = Repo.get_by(BookingRequest, id: id)

    credential = Credential.get_credential_from_broker_id(booking_request.broker_id)

    type = "CAB_NOTIFICATION"

    notification_data = get_notification_data(booking_request, identifier)

    if not is_nil(notification_data) do
      FcmNotification.send_push(
        credential.fcm_id,
        %{data: notification_data, status: identifier, type: type},
        credential.id,
        credential.notification_platform
      )
    else
      nil
    end
  end

  def get_notification_data(booking_request, identifier) do
    client_name = booking_request.client_name

    pickup_time =
      booking_request.pickup_time
      |> Timex.Timezone.convert("UTC")
      |> Timex.Timezone.convert("Asia/Kolkata")
      |> Timex.format!("%l:%M %P, %d %b, %Y", :strftime)

    case identifier do
      "vehicle_assigned" ->
        %{
          "title" => "Cab assigned for #{client_name}",
          "message" => "Cab has been assigned for booking of #{client_name} on #{pickup_time}",
          "booking_uuid" => booking_request.id
        }

      "vehicle_updated" ->
        %{
          "title" => "Cab updated for #{client_name}",
          "message" => "Cab details updated for booking of #{client_name} on #{pickup_time}",
          "booking_uuid" => booking_request.id
        }

      "booking_rejected" ->
        %{
          "title" => "Cab request cannot be fulfilled",
          "message" => "We could not fulfil your request for booking of #{client_name} on #{pickup_time}",
          "booking_uuid" => booking_request.id
        }

      _ ->
        nil
    end
  end
end
