defmodule BnApis.Subscriptions.UpdateSubscriptionStatusWorker do
  alias BnApis.Subscriptions
  alias BnApis.Subscriptions.Subscription
  alias BnApis.Repo
  alias BnApis.Helpers.FcmNotification
  alias BnApis.Accounts.Credential

  def perform(id, retries) do
    subscription = Repo.get_by(Subscription, id: id)
    response = Subscriptions.get_razorpay_subscription(subscription.razorpay_subscription_id)

    if response["status"] == Subscription.active_status() do
      broker_id = subscription.broker_id

      subscription_params = Subscriptions.get_params_for_subscription(response, broker_id, subscription.match_plus_subscription_id)

      subscription = Subscription.update_subscription!(subscription, subscription_params)
      Subscriptions.update_subscription_invoices(subscription)
      # notify app about the update
      send_notification(broker_id)
    else
      retries = retries - 1

      if retries > 0 do
        Exq.enqueue_in(
          Exq,
          "update_subscription_status",
          Subscriptions.update_status_retry_interval_in_seconds(),
          BnApis.Subscriptions.UpdateSubscriptionStatusWorker,
          [id, retries]
        )
      end
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
