defmodule BnApis.Memberships.UpdateMembershipStatusWorker do
  alias BnApis.Memberships
  alias BnApis.Memberships.Membership
  alias BnApis.Repo
  alias BnApis.Helpers.FcmNotification
  alias BnApis.Accounts.Credential

  def perform(id, retries) do
    membership = Repo.get_by(Membership, id: id)
    response = Memberships.get_paytm_membership(membership.paytm_subscription_id)

    if response["status"] == Membership.active_status() do
      broker_id = membership.broker_id

      membership_params = Memberships.get_params_for_membership(response, broker_id, membership.match_plus_membership_id)

      Membership.update_membership!(membership, membership_params)
      # notify app about the update
      send_notification(broker_id)
    else
      retries = retries - 1

      if retries > 0 do
        Exq.enqueue_in(
          Exq,
          "update_membership_status",
          Memberships.update_status_retry_interval_in_seconds(),
          BnApis.Memberships.UpdateMembershipStatusWorker,
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
