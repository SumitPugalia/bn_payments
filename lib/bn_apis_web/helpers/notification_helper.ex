defmodule BnApisWeb.Helpers.NotificationHelper do
  alias BnApis.Notifications.Request
  alias BnApis.Helpers.Time

  # these limits are per broker on daily basis
  @notification_types_limit %{
    "NEW_MATCH_ALERT" => 5,
    "NEW_STORY_ALERT" => 3
  }

  @notification_send_time_tuples {{3, 30, 00}, {15, 30, 00}}
  # a day
  @seconds_to_add 86400

  def get_notification_type_limit(notification_type) do
    @notification_types_limit[notification_type]
  end

  def send_match_notification(user_id, post_data, perfect_match \\ false) do
    if not is_nil(user_id) do
      Exq.enqueue_in(
        Exq,
        "send_notification",
        get_match_notification_send_time(),
        BnApis.SendNotificationWorker,
        [user_id, post_data, perfect_match],
        max_retries: 0
      )
    end
  end

  def get_notification_type_for_match(broker_id, perfect_match \\ false) do
    if perfect_match do
      # only in case of perfect_match we need to check limit per broker per day
      if Request.get_notification_count(broker_id, "NEW_MATCH_ALERT") < get_notification_type_limit("NEW_MATCH_ALERT") do
        "NEW_MATCH_ALERT"
      else
        "NEW_MATCH_ALERT_NOTIFICATION"
      end
    else
      "NEW_MATCH_ALERT_NOTIFICATION"
    end
  end

  def get_allowed_notification_send_time do
    current_datetime_tuple = NaiveDateTime.utc_now() |> NaiveDateTime.to_erl()
    date_tuple = current_datetime_tuple |> elem(0)
    {start_time_tuple, end_time_tuple} = @notification_send_time_tuples
    {Time.erl_to_naive({date_tuple, start_time_tuple}), Time.erl_to_naive({date_tuple, end_time_tuple})}
  end

  # returns in seconds
  def get_match_notification_send_time do
    {start_time, end_time} = get_allowed_notification_send_time()
    current_datetime = NaiveDateTime.utc_now()

    if NaiveDateTime.compare(start_time, current_datetime) == :lt and
         NaiveDateTime.compare(current_datetime, end_time) == :lt do
      # we can send notification now
      0
    else
      # schedule the notification for the next day
      NaiveDateTime.add(start_time, @seconds_to_add + add_random_seconds())
      |> NaiveDateTime.diff(current_datetime)
    end
  end

  def add_random_seconds do
    Enum.random(0..30)
  end

  def update_request_status(uuids) do
    Request.get_request_from_uuids(uuids)
    |> Enum.each(&Request.update_client_delivered_flag(&1))
  end

  def poll(user_id) do
    user_id |> Request.get_undelivered_notification_requests()
  end
end
