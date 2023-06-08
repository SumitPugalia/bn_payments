defmodule BnApis.Orders.UpdateMatchPlusCronWorker do
  alias BnApis.Orders.MatchPlus
  alias BnApis.Helpers.ApplicationHelper
  alias BnApis.Repo

  def perform() do
    channel = ApplicationHelper.get_slack_channel()

    ApplicationHelper.notify_on_slack(
      "Started match plus cron",
      channel
    )

    MatchPlus
    |> Repo.all()
    |> Enum.each(fn match_plus ->
      try do
        MatchPlus.verify_and_update_status(match_plus)
        Process.sleep(500)
      rescue
        _ ->
          ApplicationHelper.notify_on_slack(
            "Error in updating match plus for broker_id: #{match_plus.broker_id}",
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
