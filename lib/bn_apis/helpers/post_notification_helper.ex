defmodule BnApis.Helpers.PostNotificationHelper do
  alias BnApis.Helpers.{FcmNotification, SmsHelper, ApplicationHelper}

  @meta_data %{
    "NO_ACTION_ON_MATCHES" => %{
      link: "#{ApplicationHelper.deep_link_hosted_domain_url()}",
      intent: "com.dialectic.brokernetworkapp.actions.OPEN"
    },
    "EXPIRED_POSTS" => %{
      link: "#{ApplicationHelper.deep_link_hosted_domain_url()}/mypost/expired",
      intent: "com.dialectic.brokernetworkapp.actions.ACTION_OPEN_EXPIRED_POST"
    },
    "CREATE_POST" => %{
      link: "#{ApplicationHelper.deep_link_hosted_domain_url()}/createpost",
      intent: "com.dialectic.brokernetworkapp.actions.SHOW_CREATE_POST_BOTTOM_SHEET"
    },
    "NEW_POST_UPDATE" => %{
      link: "#{ApplicationHelper.deep_link_hosted_domain_url()}/createpost",
      intent: "com.dialectic.brokernetworkapp.actions.ACTION_OPEN_MY_POST_WITH_CREATE_POST"
    }
  }

  def create_post_title(clients_count, properties_count) do
    buffer = ApplicationHelper.get_buffer()
    "#{clients_count + buffer} Clients & #{properties_count + buffer} Properties"
  end

  def new_post_update_title(clients_count, properties_count, matches_count) do
    buffer = ApplicationHelper.get_buffer()
    "#{clients_count + properties_count + buffer} New Posts & #{matches_count + buffer} matches"
  end

  def expired_posts_title(expired_posts_count, post_info) do
    count = expired_posts_count - 1

    if count == 0 do
      post_info <> "post have expired."
    else
      post_info <> "+" <> "#{count} posts have expired."
    end
  end

  def no_action_on_matches_title() do
    "Matches pending"
  end

  def send_create_post_notification(credential, clients_count, properties_count) do
    data = %{
      title: create_post_title(clients_count, properties_count),
      text: "active in your locality. Create post to find matches",
      intent: %{
        action: @meta_data["CREATE_POST"][:intent]
      }
    }

    FcmNotification.send_push(
      credential.fcm_id,
      %{data: data, type: ApplicationHelper.generic_notification_type()},
      credential.id,
      credential.notification_platform
    )
  end

  def send_new_post_update_notification(credential, clients_count, properties_count, matches_count) do
    data = %{
      title: new_post_update_title(clients_count, properties_count, matches_count),
      text: "newly added today in your locality. Create post to find matches",
      intent: %{
        action: @meta_data["NEW_POST_UPDATE"][:intent]
      }
    }

    FcmNotification.send_push(
      credential.fcm_id,
      %{data: data, type: ApplicationHelper.generic_notification_type()},
      credential.id,
      credential.notification_platform
    )
  end

  def send_no_action_on_matches_notification(credential) do
    data = %{
      title: no_action_on_matches_title(),
      text: "Call before matches expire",
      intent: %{
        action: @meta_data["NO_ACTION_ON_MATCHES"][:intent]
      }
    }

    FcmNotification.send_push(
      credential.fcm_id,
      %{data: data, type: ApplicationHelper.generic_notification_type()},
      credential.id,
      credential.notification_platform
    )
  end

  def send_expired_posts_notification(credential, expired_posts_count, post_info) do
    data = %{
      title: expired_posts_title(expired_posts_count, post_info),
      text: "review all expired posts",
      intent: %{
        action: @meta_data["EXPIRED_POSTS"][:intent]
      }
    }

    FcmNotification.send_push(
      credential.fcm_id,
      %{data: data, type: ApplicationHelper.generic_notification_type()},
      credential.id,
      credential.notification_platform
    )
  end

  def send_create_post_sms(credential, clients_count, properties_count) do
    link = credential |> get_link("CREATE_POST")
    buffer = ApplicationHelper.get_buffer()

    SmsHelper.send_create_post_sms(
      credential,
      clients_count,
      properties_count,
      link,
      new_app_version?(credential),
      buffer
    )
  end

  def send_new_post_update_sms(credential, clients_count, properties_count, matches_count) do
    link = credential |> get_link("NEW_POST_UPDATE")
    buffer = ApplicationHelper.get_buffer()

    SmsHelper.send_new_post_update_sms(
      credential,
      clients_count,
      properties_count,
      matches_count,
      link,
      new_app_version?(credential),
      buffer
    )
  end

  def send_no_action_on_matches_sms(credential) do
    link = credential |> get_link("NO_ACTION_ON_MATCHES")
    SmsHelper.send_no_action_on_matches_sms(credential, link, new_app_version?(credential))
  end

  def send_expired_posts_sms(credential, expired_posts_count) do
    link = credential |> get_link("EXPIRED_POSTS")
    SmsHelper.send_expired_posts_sms(credential, expired_posts_count, link, new_app_version?(credential))
  end

  def new_app_version?(credential) do
    if is_nil(credential.app_version) do
      false
    else
      true
    end
  end

  def get_link(credential, type) do
    if new_app_version?(credential), do: @meta_data[type][:link], else: ApplicationHelper.playstore_app_url()
  end
end
