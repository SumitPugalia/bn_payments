defmodule BnApis.PostsNotification do
  alias BnApis.Accounts.Credential
  alias BnApis.Helpers.{FcmNotification, Time, PostNotificationHelper}
  alias BnApis.Posts
  alias BnApis.Notifications.Request

  # 7 pm
  @new_posts_update_time_tuple {13, 30, 00}

  def expiring_posts() do
    fetch_soon_to_expire_posts()
    |> Enum.group_by(& &1[:fcm_id])
    |> Enum.map(fn {fcm_id, notification_platform, posts} ->
      user_id = hd(posts)[:user_id]
      count = posts |> length()

      FcmNotification.send_push(
        fcm_id,
        %{data: %{count: count}, type: "EXPIRING_POSTS"},
        user_id,
        notification_platform
      )
    end)
  end

  def fetch_soon_to_expire_posts() do
    apply(Posts, :fetch_rent_client_soon_to_expire_posts, []) ++
      apply(Posts, :fetch_rent_property_soon_to_expire_posts, []) ++
      apply(Posts, :fetch_resale_client_soon_to_expire_posts, []) ++
      apply(Posts, :fetch_resale_property_soon_to_expire_posts, [])
  end

  def create_posts() do
    Credential.get_active_broker_credentials()
    |> Enum.each(fn credential ->
      latest_property_post_date = Posts.fetch_latest_property_post_query(credential.id)
      latest_client_post_date = Posts.fetch_latest_client_post_query(credential.id)

      list = [latest_client_post_date, latest_property_post_date] |> Enum.reject(&is_nil/1)

      # TODO - Limit posts count by user locality
      %{clients: clients_count, properties: properties_count} = Posts.posts_count(nil)

      case list |> length do
        0 ->
          credential |> PostNotificationHelper.send_create_post_notification(clients_count, properties_count)
          credential |> PostNotificationHelper.send_create_post_sms(clients_count, properties_count)

        _ ->
          latest_post_date = list |> Enum.max()
          latest_post_date = round(latest_post_date * 1000) |> Time.epoch_to_naive()
          now = NaiveDateTime.utc_now()
          days = (NaiveDateTime.diff(now, latest_post_date, :second) / (60 * 60 * 24)) |> round

          if days > 3 do
            credential |> PostNotificationHelper.send_create_post_notification(clients_count, properties_count)
            # credential |> PostNotificationHelper.send_create_post_sms(clients_count, properties_count)
          end
      end
    end)
  end

  def new_posts_update() do
    start_time = Time.set_datetime(Time.set_expiry_time(-1), {18, 30, 00})
    current_time = NaiveDateTime.utc_now() |> Time.set_datetime(@new_posts_update_time_tuple)

    Credential.get_active_broker_credentials()
    |> Enum.each(fn credential ->
      %{clients: clients_count, properties: properties_count} = Posts.posts_count(start_time, current_time)
      matches_count = Posts.matches_count(start_time, current_time)

      credential
      |> PostNotificationHelper.send_new_post_update_notification(clients_count, properties_count, matches_count)

      # credential |> PostNotificationHelper.send_new_post_update_sms(clients_count, properties_count, matches_count)
    end)
  end

  def expired_posts() do
    expired_time = Time.set_expiry_time(-1)

    Credential.get_active_broker_credentials()
    |> Enum.each(fn credential ->
      expired_posts_count = credential.id |> Posts.get_expired_posts_count(expired_time)

      if expired_posts_count > 0 do
        client_expired_post = Posts.fetch_expired_client_post(credential.id, expired_time) |> List.last()
        property_expired_post = Posts.fetch_expired_property_post(credential.id, expired_time) |> List.last()

        {configuration_type_ids, building_ids} =
          if is_nil(property_expired_post) do
            {client_expired_post.configuration_type_ids, client_expired_post.building_ids}
          else
            {[property_expired_post.configuration_type_id], [property_expired_post.building_id]}
          end

        post_info = Posts.post_info(configuration_type_ids, building_ids)
        credential |> PostNotificationHelper.send_expired_posts_notification(expired_posts_count, post_info)
        credential |> PostNotificationHelper.send_expired_posts_sms(expired_posts_count)
      end
    end)
  end

  def no_action_on_matches() do
    Credential.get_active_broker_credentials()
    |> Enum.reject(&is_nil(&1.last_active_at))
    |> Enum.each(fn credential ->
      latest_match_notif =
        [
          Request.get_latest_notif(credential.id, "NEW_MATCH_ALERT", "success"),
          Request.get_latest_notif(credential.id, "NEW_MATCH_ALERT_NOTIFICATION", "success")
        ]
        |> Enum.reject(&is_nil/1)

      if latest_match_notif |> length() > 0 do
        latest_match_notif_epoch_time = latest_match_notif |> Enum.map(& &1.updated_at) |> Enum.map(&Time.naive_to_epoch(&1)) |> Enum.max()

        latest_match_notif_time = latest_match_notif_epoch_time |> Time.epoch_to_naive()
        hours = (NaiveDateTime.diff(latest_match_notif_time, credential.last_active_at, :second) / (60 * 60)) |> round

        if hours >= 4 do
          credential |> PostNotificationHelper.send_no_action_on_matches_notification()
          credential |> PostNotificationHelper.send_no_action_on_matches_sms()
        end
      end
    end)
  end
end
