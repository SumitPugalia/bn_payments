defmodule BnApis.SendMesssageToSlackWorker do
  alias BnApis.Helpers.ApplicationHelper

  def perform(message) do
    channel = ApplicationHelper.get_slack_channel()

    ApplicationHelper.notify_on_slack(
      message,
      channel
    )
  end
end
