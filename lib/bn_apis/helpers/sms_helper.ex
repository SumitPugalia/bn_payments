defmodule BnApis.Helpers.SmsHelper do
  alias BnApis.Sms.SmsRequest
  alias BnApis.Helpers.ApplicationHelper

  # twilio sms statuses in lowecase, mobtexting statuses in uppercase
  @sms_statuses %{
    "queued" => 1,
    "failed" => 2,
    "sent" => 3,
    "delivered" => 4,
    "undelivered" => 5,
    "accepted" => 6,
    "sending" => 7,
    "receiving" => 8,
    "received" => 9,
    "AWAITING-DLR" => 10,
    "DELIVRD" => 11,
    "DNDNUMB" => 12,
    "DUPLICATE" => 13,
    "NOTALLOWED" => 14,
    "INV-SENDER" => 15,
    "SNDR-NOT-ALLOTED" => 16,
    "BLACKLST" => 17,
    "NO-CREDITS" => 18,
    "MOB-OFF" => 19,
    "FAILED" => 20
  }

  @sms_sender_id "BRKNET"
  @sms_templates %{
    "broker_whitelisting" => "1107166850405231568",
    "broker_login" => "1107166245214399349",
    "admin_login" => "1107166245205421835",
    "developer_login" => "1107166850434868036",
    "developer_poc_login" => "1107166850434868036",
    "general_otp" => "1107166850263152660",
    "legal_entity_poc_login" => "1107167116514601441",
    "2fa_legal_entity_poc_otp" => "1107167116522310355",
    "2fa_invoice_payout_otp" => "1107168015778199311"
  }

  def get_sender_id do
    @sms_sender_id
  end

  def get_template_id_by_name(name) do
    @sms_templates[name]
  end

  def get_status_id_by_name(name) do
    @sms_statuses[name] || @sms_statuses["FAILED"]
  end

  def get_status_callback do
    ApplicationHelper.hosted_domain_url() <> "/api/sms/message_status_webhook"
  end

  def delivery_report_url do
    ApplicationHelper.hosted_domain_url() <> "/api/mobtexting/sms/message_status_webhook"
  end

  def create_sms_request(params) do
    params |> SmsRequest.parse_params() |> SmsRequest.create_or_update_sms_request()
  end

  def create_mobtexting_sms_request(params, message) do
    params |> SmsRequest.parse_mobtexting_params(message) |> SmsRequest.create_or_update_sms_request()
  end

  def create_post_text(clients_count, properties_count, buffer \\ 0) do
    "#{clients_count + buffer} Clients & #{properties_count + buffer} Properties are active in your locality. "
  end

  def new_post_update_text(clients_count, properties_count, matches_count, buffer \\ 0) do
    "#{clients_count + properties_count + buffer} New Posts & #{matches_count + buffer} matches added today in your locality. "
  end

  def expired_posts_text(expired_posts_count) do
    common_text = "expired, restore them to keep getting matches. "

    if expired_posts_count == 1 do
      "#{expired_posts_count} post " <> common_text
    else
      "#{expired_posts_count} posts " <> common_text
    end
  end

  def no_action_on_matches_text() do
    "Multiple matches pending for your posts, call before matches expire. "
  end

  def get_sub_text(type, link, true) do
    case type do
      "CREATE_POST" ->
        "Click Here " <> "#{link} " <> "to create Post and get matches."

      "NEW_POST_UPDATE" ->
        "Click Here " <> "#{link} " <> "to create Post and get matches."

      "EXPIRED_POSTS" ->
        "Click Here " <> "#{link} " <> "to review."

      "NO_ACTION_ON_MATCHES" ->
        "Click Here " <> "#{link} " <> "to view."

      _ ->
        ""
    end <>
      ending_salutation()
  end

  def get_sub_text(_type, link, false) do
    "Click Here " <> "#{link} " <> "to update app and proceed." <> ending_salutation()
  end

  def ending_salutation() do
    "\n" <> "\n" <> "- from BrokerNetworkApp"
  end

  def create_broker_assignment_text(info) do
    "#{info[:broker_name]} has been successfully whitelisted and assigned to you." <>
      "\n" <> "Please use #{info[:otp]} OTP for sign up purpose. OTP is valid till 24hrs from now."
  end

  def send_create_post_sms(credential, clients_count, properties_count, link, new_app_version \\ false, buffer \\ 0) do
    message = create_post_text(clients_count, properties_count, buffer) <> get_sub_text("CREATE_POST", link, new_app_version)

    BnApis.Helpers.SmsService.send_sms(credential.phone_number, message, false)
  end

  def send_new_post_update_sms(
        credential,
        clients_count,
        properties_count,
        matches_count,
        link,
        new_app_version \\ false,
        buffer \\ 0
      ) do
    message =
      new_post_update_text(clients_count, properties_count, matches_count, buffer) <>
        get_sub_text("NEW_POST_UPDATE", link, new_app_version)

    BnApis.Helpers.SmsService.send_sms(credential.phone_number, message, false)
  end

  def send_expired_posts_sms(credential, expired_posts_count, link, new_app_version \\ false) do
    message = expired_posts_text(expired_posts_count) <> get_sub_text("EXPIRED_POSTS", link, new_app_version)
    BnApis.Helpers.SmsService.send_sms(credential.phone_number, message, false)
  end

  def send_no_action_on_matches_sms(credential, link, new_app_version \\ false) do
    message = no_action_on_matches_text() <> get_sub_text("NO_ACTION_ON_MATCHES", link, new_app_version)
    BnApis.Helpers.SmsService.send_sms(credential.phone_number, message, false)
  end

  def send_broker_assigned_sms(_employee_credential = %{phone_number: phone_number, country_code: country_code}, info) do
    message = create_broker_assignment_text(info)
    full_phone = country_code <> phone_number
    BnApis.Helpers.SmsService.send_sms(full_phone, message, false)
    Exq.enqueue(Exq, "send_otp_sms", BnApis.SendOtpSmsWorker, [phone_number, info[:otp]])
  end
end
