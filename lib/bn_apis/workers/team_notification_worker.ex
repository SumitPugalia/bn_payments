defmodule BnApis.TeamNotificationWorker do
  @moduledoc """
    Worker responsible for sending notification related to teams.
  """

  def perform(user_uuid) do
    BnApis.SendNotificationWorker.send_team_notification(user_uuid)
  end
end
