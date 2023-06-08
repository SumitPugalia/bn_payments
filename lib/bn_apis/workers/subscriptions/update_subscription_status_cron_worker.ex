defmodule BnApis.Subscriptions.UpdateSubscriptionStatusCronWorker do
  alias BnApis.Subscriptions
  alias BnApis.Subscriptions.Subscription
  alias BnApis.Repo
  alias BnApis.Helpers.FcmNotification
  alias BnApis.Accounts.Credential

  import Ecto.Query

  def perform() do
    Subscription
    |> where(
      [s],
      s.is_client_side_registration_successful == true and
        (s.status == ^Subscription.created_status() or s.status == ^Subscription.authenticated_status())
    )
    |> Repo.all()
    |> Enum.each(fn subscription ->
      update_subscription_status(subscription)
      Process.sleep(500)
    end)
  end

  def update_subscription_status(subscription) do
    response = Subscriptions.get_razorpay_subscription(subscription.razorpay_subscription_id)

    if response["status"] == Subscription.active_status() do
      broker_id = subscription.broker_id

      subscription_params = Subscriptions.get_params_for_subscription(response, broker_id, subscription.match_plus_subscription_id)

      subscription = Subscription.update_subscription!(subscription, subscription_params)
      Subscriptions.update_subscription_invoices(subscription)
      # notify app about the update
      send_notification(broker_id)
    end
  end

  def send_notification(broker_id) do
    credential = Credential.get_credential_from_broker_id(broker_id)
    type = "SUBSCRIPTION_CONFIRMED"

    FcmNotification.send_push(
      credential.fcm_id,
      %{data: %{}, type: type},
      credential.id,
      credential.notification_platform
    )
  end
end
