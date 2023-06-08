defmodule BnApis.Memberships.UpdatePendingMembershipStatusCronWorker do
  alias BnApis.Repo

  alias BnApis.Memberships
  alias BnApis.Memberships.Membership
  alias BnApis.Helpers.ApplicationHelper

  import Ecto.Query

  def perform() do
    update_pending_orders()
    update_expired_orders()
  end

  def update_pending_orders() do
    exclude_statuses = [
      Membership.active_status(),
      Membership.authorization_failed_status(),
      Membership.reject_status(),
      Membership.suspended_status(),
      Membership.closed_status()
    ]

    Membership
    |> where([m], m.status not in ^exclude_statuses)
    |> Repo.all()
    |> Enum.each(fn membership ->
      update_memberships_status(membership)
      Process.sleep(500)
    end)
  end

  def update_expired_orders() do
    now = Timex.now() |> Timex.Timezone.convert("Asia/Kolkata") |> DateTime.to_unix()
    statuses = [Membership.active_status()]

    Membership
    |> where([m], m.status in ^statuses)
    |> where([m], m.current_end <= ^now)
    |> Repo.all()
    |> Enum.each(fn membership ->
      update_memberships_status(membership)
      Process.sleep(500)
    end)
  end

  def update_memberships_status(membership) do
    try do
      response = Memberships.get_paytm_membership(membership.paytm_subscription_id)

      membership_params = Memberships.get_params_for_membership(response, membership.broker_id, membership.match_plus_membership_id)

      Membership.update_membership!(membership, membership_params)
    rescue
      e in _ ->
        channel = ApplicationHelper.get_slack_channel()

        ApplicationHelper.notify_on_slack(
          "Error in UpdatePendingMembershipStatusCronWorker for membership #{membership.id} because of #{Exception.message(e.message || e)}",
          channel
        )
    end
  end
end
