defmodule BnApis.StoryBroadcastWorker do
  alias BnApisWeb.Helpers.StoryHelper

  def perform(user_id, story_uuid, user_uuids, template_name, app_version \\ "102029", notif_type \\ "NEW_STORY_ALERT") do
    user_uuids = if is_nil(user_uuids) or user_uuids == "", do: [], else: user_uuids |> String.split(",")
    story_uuid |> StoryHelper.send_story_alert(user_uuids, app_version, template_name, user_id, notif_type)
  end
end
