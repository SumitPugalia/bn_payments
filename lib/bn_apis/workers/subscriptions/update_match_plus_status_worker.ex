defmodule BnApis.Subscriptions.UpdateMatchPlusStatusWorker do
  alias BnApis.Subscriptions.MatchPlusSubscription
  alias BnApis.Helpers.ApplicationHelper
  alias BnApis.Repo

  def perform() do
    channel = ApplicationHelper.get_slack_channel()

    ApplicationHelper.notify_on_slack(
      "Started updating match plus statuses",
      channel
    )

    MatchPlusSubscription
    |> Repo.all()
    |> Enum.each(fn match_plus_subscription ->
      try do
        MatchPlusSubscription.verify_and_update_status(match_plus_subscription)
        Process.sleep(500)
      rescue
        _ ->
          ApplicationHelper.notify_on_slack(
            "Error in updating match plus status with broker_id: #{match_plus_subscription.broker_id}",
            channel
          )
      end
    end)

    ApplicationHelper.notify_on_slack(
      "Finished updating match plus statuses",
      channel
    )
  end
end
