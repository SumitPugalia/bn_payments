defmodule BnApis.Commercial.UpdateCommercialChannelUsers do
  import Ecto.Query
  alias BnApis.Helpers.ExternalApiHelper
  alias alias BnApis.Commercials.CommercialSendbird
  alias BnApis.Commercials.CommercialPropertyPost
  alias BnApis.Commercials.CommercialChannelUrlMapping
  alias BnApis.Helpers.ApplicationHelper
  alias BnApis.Repo

  @max_retries 5

  def perform(_, _, _, _retry = 0), do: :ignore

  def perform(commercial_post_id, added_employee_ids, removed_employee_ids, retry) do
    try do
      added_employee_uuids = CommercialSendbird.get_all_employee_uuids(added_employee_ids)
      removed_employee_uuids = CommercialSendbird.get_all_employee_uuids(removed_employee_ids)
      post = Repo.get_by(CommercialPropertyPost, id: commercial_post_id)
      added_employee_ids |> Enum.map(&CommercialSendbird.register_commercial_user_on_sendbird(&1))

      CommercialChannelUrlMapping
      |> where([m], m.commercial_property_post_id == ^post.id and m.is_active == ^true and not is_nil(m.channel_url))
      |> Repo.all()
      |> Enum.map(fn cm ->
        update_channel_users(added_employee_uuids, removed_employee_uuids, cm.channel_url)
      end)

      {:ok, "Updated Successfully"}
    rescue
      err ->
        retry_count = @max_retries - retry + 1
        channel = ApplicationHelper.get_slack_channel()

        ApplicationHelper.notify_on_slack(
          "Issue in UpdateCommercialChannelUsers cron for post_id:#{commercial_post_id},#{added_employee_ids},#{removed_employee_ids}, retry_count:#{retry_count},error:#{Exception.message(err)}",
          channel
        )

        Exq.enqueue_in(Exq, "commercial_sendbird", retry_count * 10, BnApis.Commercial.UpdateCommercialChannelUsers, [
          commercial_post_id,
          added_employee_ids,
          removed_employee_ids,
          retry - 1
        ])
    end
  end

  def update_channel_users(added_employee_uuids, removed_employee_uuids, channel_url) do
    # remove old employee from channel
    payload = %{"user_ids" => removed_employee_uuids}
    ExternalApiHelper.remove_user_from_channel(payload, channel_url)

    # add new employee to channel
    payload = %{"user_ids" => added_employee_uuids}
    ExternalApiHelper.add_user_to_channel(payload, channel_url)
  end
end
