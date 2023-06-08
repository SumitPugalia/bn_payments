defmodule BnApis.Projects.RewardsActivatedWeeklyNotificationWorker do
  import Ecto.Query
  alias BnApis.Repo
  alias BnApis.Helpers.{ApplicationHelper, Redis}
  alias BnApis.Accounts.Credential
  alias BnApis.Organizations.Broker
  alias BnApis.Places.City
  alias BnApis.Stories.Story

  @starting_msg "Starting to send rewards activated weekly notification"
  @completion_msg "Finished sending rewards activated weekly notification"
  @channel ApplicationHelper.get_slack_channel()
  def perform() do
    try do
      ApplicationHelper.notify_on_slack(
        @starting_msg,
        @channel
      )

      sv_rewards_active_stories = get_sv_rewards_activated_story_list()
      booking_rewards_active_stories = get_booking_rewards_activated_story_list()

      {sv_reward_story_map, booking_reward_story_map} = generate_city_wise_story_lists(sv_rewards_active_stories, booking_rewards_active_stories)

      send_notifications_to_credentials(sv_reward_story_map, booking_reward_story_map)

      ApplicationHelper.notify_on_slack(
        @completion_msg,
        @channel
      )
    rescue
      err ->
        ApplicationHelper.notify_on_slack(
          "Error in sending rewards activated notification: #{Exception.message(err)}",
          @channel
        )
    end
  end

  def get_sv_rewards_activated_story_list() do
    {:ok, story_ids} = Redis.q(["LRANGE", "sv_rewards_activated_last_week", 0, -1])
    Redis.q(["DEL", "sv_rewards_activated_last_week"])

    Story
    |> where([s], s.id in ^story_ids)
    |> select([s], %{story_name: s.name, operating_cities: s.operating_cities})
    |> Repo.all()
  end

  def get_booking_rewards_activated_story_list() do
    {:ok, story_ids} = Redis.q(["LRANGE", "booking_rewards_activated_last_week", 0, -1])
    Redis.q(["DEL", "booking_rewards_activated_last_week"])

    Story
    |> where([s], s.id in ^story_ids)
    |> select([s], %{story_name: s.name, operating_cities: s.operating_cities})
    |> Repo.all()
  end

  def generate_city_wise_story_lists(sv_rewards_story_list, booking_rewards_story_list) do
    city_ids =
      City
      |> select([city], city.id)
      |> Repo.all()

    city_wise_story_map = Enum.reduce(city_ids, %{}, fn x, acc -> Map.put(acc, x, "") end)

    sv_reward_story_map =
      Enum.reduce(sv_rewards_story_list, city_wise_story_map, fn x, acc ->
        Enum.reduce(x.operating_cities, acc, fn cid, acc -> Map.put(acc, cid, acc[cid] <> x.story_name <> ", ") end)
      end)

    sv_reward_story_map = Enum.reduce(sv_reward_story_map, %{}, fn {k, v}, acc -> Map.put(acc, k, String.trim_trailing(v, ", ")) end)

    city_wise_story_map = Enum.reduce(city_ids, %{}, fn x, acc -> Map.put(acc, x, "") end)

    booking_reward_story_map =
      Enum.reduce(booking_rewards_story_list, city_wise_story_map, fn x, acc ->
        Enum.reduce(x.operating_cities, acc, fn cid, acc -> Map.put(acc, cid, acc[cid] <> x.story_name <> ", ") end)
      end)

    booking_reward_story_map = Enum.reduce(booking_reward_story_map, %{}, fn {k, v}, acc -> Map.put(acc, k, String.trim_trailing(v, ", ")) end)

    {sv_reward_story_map, booking_reward_story_map}
  end

  def send_notifications_to_credentials(sv_reward_story_map, booking_reward_story_map) do
    stream =
      Credential
      |> join(:inner, [c], b in Broker, on: b.id == c.broker_id)
      |> where([c, b], c.active == true and not is_nil(c.fcm_id) and c.fcm_id != "" and not is_nil(b.operating_city))
      |> select([c, b], %{"id" => c.id, "fcm_id" => c.fcm_id, "platform" => c.notification_platform, "city" => b.operating_city})
      |> Repo.stream()
      |> Stream.each(fn cred -> send_notification(cred, sv_reward_story_map, booking_reward_story_map) end)

    Repo.transaction(fn -> Stream.run(stream) end)
  end

  def send_notification(cred, sv_reward_story_map, booking_reward_story_map) do
    try do
      send_sv_reward_enabled_notification(cred, sv_reward_story_map, sv_reward_story_map[cred["city"]])
      send_booking_reward_enabled_notification(cred, booking_reward_story_map, booking_reward_story_map[cred["city"]])
    rescue
      err ->
        ApplicationHelper.notify_on_slack(
          "Error in sending rewards activated notification: #{Exception.message(err)}",
          @channel
        )
    end
  end

  def send_sv_reward_enabled_notification(_cred, _sv_reward_story_map, ""), do: :ok
  def send_sv_reward_enabled_notification(_cred, _sv_reward_story_map, nil), do: :ok

  def send_sv_reward_enabled_notification(cred, sv_reward_story_map, _data) do
    title = "Register your site visits and get rewarded!"
    message = "You can now earn rewards in #{sv_reward_story_map[cred["city"]]}"
    intent = "com.dialectic.brokernetworkapp.actions.PROJECT"
    type = "GENERIC_NOTIFICATION"
    data = %{"title" => title, "message" => message, "intent" => intent}
    push_notification(cred, %{"data" => data, "type" => type})
  end

  def send_booking_reward_enabled_notification(_cred, _booking_reward_story_map, ""), do: :ok
  def send_booking_reward_enabled_notification(_cred, _booking_reward_story_map, nil), do: :ok

  def send_booking_reward_enabled_notification(cred, booking_reward_story_map, _data) do
    title = "Register your bookings and get rewarded!"
    message = "You can now earn rewards in #{booking_reward_story_map[cred["city"]]}"
    intent = "com.dialectic.brokernetworkapp.actions.PROJECT"
    type = "GENERIC_NOTIFICATION"
    data = %{"title" => title, "message" => message, "intent" => intent}
    push_notification(cred, %{"data" => data, "type" => type})
  end

  def push_notification(cred, notif_data = %{"data" => _data, "type" => _type}) do
    Exq.enqueue(Exq, "send_rewards_enabled_notification", BnApis.Notifications.PushNotificationWorker, [
      cred["fcm_id"],
      notif_data,
      cred["id"],
      cred["platform"]
    ])
  end
end
