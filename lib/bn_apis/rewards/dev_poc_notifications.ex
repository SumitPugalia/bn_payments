defmodule BnApis.Rewards.DevPocNotifications do
  alias BnApis.Helpers.{ApplicationHelper}

  @create_lead_whatsapp_template "builder_1"
  @manager_approval_whatsapp_notif_template "builder_2"
  @auto_approval_whatsapp_notif_template "builder_3"
  @auto_approval_reminder_whatsapp_notif_template "builder_4"
  @sv_lead_summary_whatsapp_notif_template "builder_5"

  @channel ApplicationHelper.get_slack_channel()

  def perform(
        @create_lead_whatsapp_template,
        dev_poc_cred_id,
        dev_poc_cred_fcm_id,
        dev_poc_cred_platform,
        dev_poc_cred_phone_number,
        story_name,
        broker_name,
        broker_phone_number,
        lead_name
      ),
      do:
        send_new_lead_created_notification_to_developer_poc(
          dev_poc_cred_id,
          dev_poc_cred_fcm_id,
          dev_poc_cred_platform,
          dev_poc_cred_phone_number,
          story_name,
          broker_name,
          broker_phone_number,
          lead_name
        )

  def perform(
        @manager_approval_whatsapp_notif_template,
        status,
        lead_name,
        lead_visit_date,
        broker_name,
        story_name,
        dev_poc_cred_id,
        dev_poc_cred_fcm_id,
        dev_poc_cred_platform,
        dev_poc_cred_phone_number,
        manager_name,
        manager_phone_number,
        broker_phone_number
      ),
      do:
        maybe_send_sv_reward_approved_by_manager_notification_to_dev_poc(
          status,
          lead_name,
          lead_visit_date,
          broker_name,
          story_name,
          dev_poc_cred_id,
          dev_poc_cred_fcm_id,
          dev_poc_cred_platform,
          dev_poc_cred_phone_number,
          manager_name,
          manager_phone_number,
          broker_phone_number
        )

  def perform(
        @auto_approval_whatsapp_notif_template,
        lead_name,
        lead_visit_date,
        broker_name,
        story_name,
        dev_poc_cred_id,
        dev_poc_cred_fcm_id,
        dev_poc_cred_platform,
        dev_poc_cred_phone_number,
        broker_phone_number
      ),
      do:
        send_auto_approved_notification_to_dev_poc(
          lead_name,
          lead_visit_date,
          broker_name,
          story_name,
          dev_poc_cred_id,
          dev_poc_cred_fcm_id,
          dev_poc_cred_platform,
          dev_poc_cred_phone_number,
          broker_phone_number
        )

  def maybe_send_sv_reward_approved_by_manager_notification_to_dev_poc(
        "pending",
        lead_name,
        lead_visit_date,
        broker_name,
        story_name,
        dev_poc_cred_id,
        dev_poc_cred_fcm_id,
        dev_poc_cred_platform,
        dev_poc_cred_phone_number,
        manager_name,
        manager_phone_number,
        broker_phone_number
      ) do
    notif_data = %{
      "type" => "GENERIC_NOTIFICATION",
      "data" => %{
        "title" => "SV Reward Approved by RM",
        "message" =>
          "Site Visit with customer name #{lead_name}, on #{lead_visit_date} by #{broker_name}, #{broker_phone_number} on #{story_name} is verified by relationship manager #{manager_name}, #{manager_phone_number}. Click here to take action.",
        "action" => "com.dialectic.brokernetwork.builder.actions.SV.APPROVED"
      }
    }

    send_fcm_notification(dev_poc_cred_id, dev_poc_cred_fcm_id, dev_poc_cred_platform, notif_data)

    send_whatsapp_notification(dev_poc_cred_phone_number, @manager_approval_whatsapp_notif_template, [
      lead_name,
      lead_visit_date,
      broker_name,
      broker_phone_number,
      story_name,
      manager_name,
      manager_phone_number
    ])
  end

  def maybe_send_sv_reward_approved_by_manager_notification_to_dev_poc(
        _status,
        _lead_name,
        _lead_visit_date,
        _broker_name,
        _story_name,
        _dev_poc_cred_id,
        _dev_poc_cred_fcm_id,
        _dev_poc_cred_platform,
        _dev_poc_cred_phone_number,
        _manager_name,
        _manager_phone_number,
        _broker_phone_number
      ),
      do: :ok

  def send_new_lead_created_notification_to_developer_poc(
        developer_poc_credential_id,
        developer_poc_credential_fcm_id,
        developer_poc_credential_platform,
        developer_poc_credential_phone_number,
        story_name,
        broker_name,
        broker_phone_number,
        lead_name
      ) do
    notif_data = %{
      "type" => "GENERIC_NOTIFICATION",
      "data" => %{
        "title" => "New SV Reward Claimed",
        "message" => "New Stie Visit claimed at #{story_name} by #{broker_name}, #{broker_phone_number} with customer name as #{lead_name}. Click here to take action.",
        "action" => "com.dialectic.brokernetwork.builder.actions.SV.NEW"
      }
    }

    send_fcm_notification(developer_poc_credential_id, developer_poc_credential_fcm_id, developer_poc_credential_platform, notif_data)
    send_whatsapp_notification(developer_poc_credential_phone_number, @create_lead_whatsapp_template, [story_name, broker_name, broker_phone_number, lead_name])
  end

  def send_auto_approved_notification_to_dev_poc(
        lead_name,
        lead_visit_date,
        broker_name,
        story_name,
        dev_poc_cred_id,
        dev_poc_cred_fcm_id,
        dev_poc_cred_platform,
        dev_poc_cred_phone_number,
        broker_phone_number
      ) do
    notif_data = %{
      "type" => "GENERIC_NOTIFICATION",
      "data" => %{
        "title" => "SV Reward Auto Approved",
        "message" => "Site Visit with customer name #{lead_name} on #{lead_visit_date} by #{broker_name}, #{broker_phone_number} on #{story_name} has been approved for rewards.",
        "action" => "com.dialectic.brokernetwork.builder.actions.SV.AUTO_APPROVED"
      }
    }

    send_fcm_notification(dev_poc_cred_id, dev_poc_cred_fcm_id, dev_poc_cred_platform, notif_data)

    send_whatsapp_notification(dev_poc_cred_phone_number, @auto_approval_whatsapp_notif_template, [
      lead_name,
      lead_visit_date,
      broker_name,
      broker_phone_number,
      story_name
    ])
  end

  def send_reminder_notification_to_developer_poc(lead) do
    notif_data = %{
      "type" => "GENERIC_NOTIFICATION",
      "data" => %{
        "title" => "SV Leads will be auto approved.",
        "message" =>
          "#{lead["lead_count"]} site visits are verified by relationship managers and awaiting your approval. These visits will be auto approved for rewards in next 24 hours.",
        "action" => "com.dialectic.brokernetwork.builder.actions.SV.NEW"
      }
    }

    try do
      send_fcm_notification(lead["developer_poc_credential_id"], lead["developer_poc_credential_fcm_id"], lead["developer_poc_credential_platform"], notif_data)
      send_whatsapp_notification(lead["developer_poc_credential_phone_number"], @auto_approval_reminder_whatsapp_notif_template, [Integer.to_string(lead["lead_count"])])
    rescue
      err ->
        ApplicationHelper.notify_on_slack(
          "Error in Automated SV Lead Reminders notification: #{Exception.message(err)}",
          @channel
        )
    end
  end

  def send_summary_notification_to_developer_poc(0, _lead, _), do: :ok

  def send_summary_notification_to_developer_poc(_, lead, story_names) do
    notif_data = %{
      "type" => "GENERIC_NOTIFICATION",
      "data" => %{
        "title" => "SV Leads Summary",
        "message" => "#{lead["lead_count"]} site visits were claimed today at #{story_names}. Visit all site visits.",
        "action" => "com.dialectic.brokernetwork.builder.actions.SV"
      }
    }

    try do
      send_fcm_notification(lead["developer_poc_credential_id"], lead["developer_poc_credential_fcm_id"], lead["developer_poc_credential_platform"], notif_data)
      send_whatsapp_notification(lead["developer_poc_credential_phone_number"], @sv_lead_summary_whatsapp_notif_template, [Integer.to_string(lead["lead_count"]), story_names])
    rescue
      err ->
        ApplicationHelper.notify_on_slack(
          "Error in SV Summary notification: #{Exception.message(err)}",
          @channel
        )
    end
  end

  defp send_fcm_notification(developer_poc_credential_id, developer_poc_credential_fcm_id, developer_poc_credential_platform, notif_data) do
    Exq.enqueue(Exq, "push_notification", BnApis.Notifications.PushNotificationWorker, [
      developer_poc_credential_fcm_id,
      notif_data,
      developer_poc_credential_id,
      developer_poc_credential_platform
    ])
  end

  defp send_whatsapp_notification(developer_poc_credential_phone_number, template_id, params) do
    Exq.enqueue(Exq, "send_whatsapp_message", BnApis.Whatsapp.SendWhatsappMessageWorker, [
      developer_poc_credential_phone_number,
      template_id,
      params
    ])
  end
end
