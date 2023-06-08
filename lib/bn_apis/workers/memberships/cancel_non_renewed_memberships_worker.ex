defmodule BnApis.Memberships.CancelNonRenewedMembershipsWorker do
  alias BnApis.Repo

  alias BnApis.Memberships
  alias BnApis.Memberships.Membership
  alias BnApis.Helpers.ApplicationHelper

  import Ecto.Query

  def perform() do
    cancel_expired_orders()
  end

  def cancel_expired_orders() do
    three_days_ago =
      Timex.now()
      |> Timex.Timezone.convert("Asia/Kolkata")
      |> Timex.end_of_day()
      |> Timex.shift(days: -4)
      |> DateTime.to_unix()

    Membership
    |> where([m], m.status == ^Membership.active_status())
    |> where([m], m.current_end < ^three_days_ago)
    |> Repo.all()
    |> Enum.each(fn membership ->
      try do
        cancel_membership(membership)
      rescue
        e in _ ->
          channel = ApplicationHelper.get_slack_channel()

          ApplicationHelper.notify_on_slack(
            "Error in CancelNonRenewedMembershipsWorker for membership #{membership.id} because of #{Exception.message(e.message || e)}",
            channel
          )
      end

      Process.sleep(500)
    end)
  end

  def cancel_membership(membership) do
    {status_code, _response} = Memberships.cancel_paytm_membership(membership.paytm_subscription_id)

    if status_code == 200 do
      response = Memberships.get_paytm_membership(membership.paytm_subscription_id)

      membership_params = Memberships.get_params_for_membership(response, membership.broker_id, membership.match_plus_membership_id)

      Membership.update_membership!(membership, membership_params)
    end
  end
end
