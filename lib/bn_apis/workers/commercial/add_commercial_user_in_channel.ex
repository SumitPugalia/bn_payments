defmodule BnApis.Commercial.AddCommercialUserInChannel do
  import Ecto.Query

  alias BnApis.Repo
  alias BnApis.Helpers.ExternalApiHelper
  alias BnApis.Accounts.EmployeeCredential
  alias BnApis.Commercials.CommercialChannelUrlMapping
  alias BnApis.Commercials.CommercialSendbird
  alias BnApis.Helpers.ApplicationHelper
  alias BnApis.Accounts.EmployeeRole

  def perform() do
    channel = ApplicationHelper.get_slack_channel()

    ApplicationHelper.notify_on_slack(
      "Started Automatically commercial admin assign in channel urls via cron",
      channel
    )

    add_users_in_channel(EmployeeRole.commercial_admin().id)

    ApplicationHelper.notify_on_slack(
      "Finished Automatically commercial admin assign in channel urls via cron",
      channel
    )
  end

  def add_users_in_channel(role_id) do
    users = EmployeeCredential |> where([e], e.employee_role_id == ^role_id and e.active == ^true) |> Repo.all()
    channels = get_last_7_days_records()

    users
    |> Enum.each(fn user ->
      CommercialSendbird.register_commercial_user_on_sendbird(user.id)

      channels
      |> Enum.each(fn channel ->
        if not Enum.member?(channel.user_ids, user.id) do
          add_user_in_channel(user, channel)
        end
      end)
    end)
  end

  def add_user_in_channel(user, channel) do
    try do
      if(ExternalApiHelper.is_user_already_exist_in_channel(channel.channel_url, user.uuid) == false) do
        payload = %{"user_ids" => [user.uuid]}
        ExternalApiHelper.add_user_to_channel(payload, channel.channel_url)
      end

      CommercialChannelUrlMapping.update(channel, %{"user_ids" => [user.id | channel.user_ids]})
    rescue
      err ->
        slack_channel = ApplicationHelper.get_slack_channel()

        ApplicationHelper.notify_on_slack(
          "error occurred while assigning commercial employee in channel url for user:#{user.uuid} and channel:#{channel.channel_url}, error:#{Exception.message(err)}",
          slack_channel
        )
    end
  end

  def get_last_7_days_records() do
    start_time = Timex.now() |> Date.add(-7) |> Timex.Timezone.convert("Asia/Kolkata")
    beginning_of_the_start_time = Timex.beginning_of_day(start_time)

    CommercialChannelUrlMapping
    |> where([c], c.updated_at >= ^beginning_of_the_start_time)
    |> where([c], not is_nil(c.channel_url) and c.is_active == ^true)
    |> Repo.all()
  end
end
