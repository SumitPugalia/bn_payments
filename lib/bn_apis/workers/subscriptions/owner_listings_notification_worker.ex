defmodule BnApis.Subscriptions.OwnerListingsNotificationWorker do
  import Ecto.Query, warn: false
  alias BnApis.Repo
  alias BnApis.Helpers.FcmNotification
  alias BnApis.Accounts.Credential

  def perform(title, message, phone_number) do
    phone_number =
      if is_integer(phone_number),
        do: Integer.to_string(phone_number),
        else: phone_number

    Credential
    |> where([cred], cred.active == true)
    |> where([cred], cred.phone_number == ^phone_number)
    |> where([cred], not is_nil(cred.fcm_id))
    |> Repo.all()
    |> Enum.each(fn credential ->
      send_notification(credential, title, message)
    end)
  end

  def send_notification(credential, title, message) do
    type = "NEW_OWNER_LISTINGS"
    data = %{"title" => title, "message" => message}

    FcmNotification.send_push(
      credential.fcm_id,
      %{data: data, type: type},
      credential.id,
      credential.notification_platform
    )
  end
end
