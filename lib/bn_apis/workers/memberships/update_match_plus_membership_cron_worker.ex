defmodule BnApis.Memberships.UpdateMatchPlusMembershipCronWorker do
  alias BnApis.Memberships.MatchPlusMembership
  alias BnApis.Helpers.ApplicationHelper
  alias BnApis.Repo

  def perform() do
    channel = ApplicationHelper.get_slack_channel()

    ApplicationHelper.notify_on_slack(
      "Started match plus cron",
      channel
    )

    MatchPlusMembership
    |> Repo.all()
    |> Enum.each(fn match_plus_membership ->
      try do
        MatchPlusMembership.verify_and_update_status(match_plus_membership)
        Process.sleep(500)
      rescue
        _ ->
          ApplicationHelper.notify_on_slack(
            "Error in updating match plus membership for broker_id: #{match_plus_membership.broker_id}",
            channel
          )
      end
    end)

    ApplicationHelper.notify_on_slack(
      "Finished match plus cron",
      channel
    )
  end
end
