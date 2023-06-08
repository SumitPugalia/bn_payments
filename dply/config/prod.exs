import Config

# For production, don't forget to configure the url host
# to something meaningful, Phoenix uses this information
# when generating URLs.
#
# The watchers configuration can be used to run external
# watchers to your application. For example, we use it
# with webpack to recompile .js and .css sources.
config :bn_apis, BnApisWeb.Endpoint,
  http: [
    ip: {0, 0, 0, 0, 0, 0, 0, 0},
    port: System.get_env("PORT") || 4005
  ],
  debug_errors: false,
  code_reloader: false,
  check_origin: false,
  secret_key_base: "dVNTb8DiLITnihqBvQV5IqaZq4Unbsx+bntnGFh7FDjYMlP9B9oaET7qOUT+eFek"

config :bn_apis, BnApisWeb.Endpoint, cache_static_manifest: "priv/static/cache_manifest.json"

config :ex_aws,
  access_key_id: <%= config["aws.access_key_id"] %>,
  secret_access_key: <%= config["aws.secret_access_key"] %>,
  temp_bucket: <%= config["aws.temp_bucket"] %>,
  files_bucket: <%= config["aws.files_bucket"] %>

config :bn_apis,
  server_env: <%= config["server_env"] %>,
  twilio_account_sid: <%= config["twilio.account_sid"] %>,
  twilio_auth_token: <%= config["twilio.auth_token"] %>,
  twilio_endpoint: "https://api.twilio.com/2010-04-01/Accounts/",
  bulksms_url: <%= config["bulksms.url"] %>,
  bulksms_apikey: <%= config["bulksms.apikey"] %>,
  bulksms_entity_id: <%= config["bulksms.entity_id"] %>,
  twilio_from: <%= config["twilio.from"] %>,
  default_dev_twilio_to: "+918879006228",
  whitelisted_dev_twilio_tos: "phone_number1, phone_number2, phone_number3",
  apxor: %{
    enable_apxor_sdk: <%= config["apxor.enable_apxor_sdk"] %>,
    ios_app_id: <%= config["apxor.ios_app_id"] %>,
    android_app_id: <%= config["apxor.android_app_id"] %>
  },
  mobtexting: %{
    token: <%= config["mobtexting.token"] %>,
    send_endpoint: <%= config["mobtexting.send_endpoint"] %>,
    enabled: <%= config["mobtexting.enabled"] %>
  },
  sendbird: %{
    application_id: <%= config["sendbird.application_id"] %>,
    api_token: <%= config["sendbird.api_token"] %>
  },
  #Without trailing slash
  hosted_domain_url: <%= config["hosted_domain_url"] %>,
  deep_link_hosted_domain_url: <%= config["deep_link_hosted_domain_url"] %>,
  #Without trailing slash
  playstore_app_url: <%= config["playstore_app_url"] %>,
  bn_web_base_url: <%= config["bn_web_base_url"] %>,
  secret_salt: "hare_krishna",
  more_vals: "",
  sms_token: "6VWwBfbh2yd",
  imgix_domain: <%= config["imgix_domain"] %>,
  deep_link_app_version: <%= config["deep_link_app_version"] %>,
  slack_url: "https://slack.com/api/chat.postMessage",
  slack_token: <%= config["slack_token"] %>,
  slack_channel: <%= config["slack_channel"] %>,
  slack_building_channel: <%= config["slack_building_channel"] %>,
  match_plus_customer_support_number: <%= config["match_plus_customer_support_number"] %>,
  match_plus_original_price: <%= config["match_plus_original_price"] %>,
  match_plus_price: <%= config["match_plus_price"] %>,
  match_plus_offer_title: <%= config["match_plus_offer_title"] %>,
  match_plus_offer_text: <%= config["match_plus_offer_text"] %>,
  customer_support_number: <%= config["customer_support_number"] %>,
  mumbai_customer_support_number: <%= config["mumbai_customer_support_number"] %>,
  meta_service_url: <%= config["meta_service_url"] %>,
  ivr_masked_number: <%= config["ivr_masked_number"] %>,
  ivr_app_id: <%= config["ivr_app_id"] %>,
  ivr_sid: <%= config["ivr_sid"] %>,
  ivr_token: <%= config["ivr_token"] %>,
  virtual_number: <%= config["virtual_number"] %>,
  mumbai_customer_support_person: <%= config["mumbai_customer_support_person"] %>,
  pune_customer_support_person: <%= config["pune_customer_support_person"] %>,
  default_customer_support_person: <%= config["default_customer_support_person"] %>,
  places_key: <%= config["places_key"] %>,
  db_query_key: <%= config["db_query_key"] %>,
  razorpay_url:  <%= config["razorpay_url"] %>,
  razorpay_username: <%= config["razorpay_username"] %>,
  razorpay_password: <%= config["razorpay_password"] %>,
  razorpay_account_number: <%= config["razorpay_account_number"] %>,
  razorpay_match_plus_plan_id: <%= config["razorpay_match_plus_plan_id"] %>,
  razorpay_webhook_secret_key: <%= config["razorpay_webhook_secret_key"] %>,
  razorpay_ifsc_url: <%= config["razorpay_ifsc_url"] %>,
  paytm_merchant_key: <%= config["paytm_merchant_key"] %>,
  paytm_merchant_id: <%= config["paytm_merchant_id"] %>,
  paytm_url: <%= config["paytm_url"] %>,
  paytm_website_mode: <%= config["paytm_website_mode"] %>,
  paytm_subscription_amount: <%= config["paytm_subscription_amount"] %>,
  paytm_subscription_validity_in_days: <%= config["paytm_subscription_validity_in_days"] %>,
  paytm_subscription_frequency_unit: <%= config["paytm_subscription_frequency_unit"] %>,
  paytm_subscription_enabled: <%= config["paytm_subscription_enabled"] %>,
  slash_url: <%= config["slash_url"] %>,
  slash_username: <%= config["slash_username"] %>,
  slash_password: <%= config["slash_password"] %>,
  bn_apis_base_url: <%= config["bn_apis_base_url"] %>,
  attestr_auth_key: <%= config["attestr_auth_key"] %>,
  attestr_pan_url:  <%= config["attestr_pan_url"] %>,
  attestr_url:  <%= config["attestr_url"] %>,
  attestr_gstin_url:  <%= config["attestr_gstin_url"] %>,
  leadsquared_url:  <%= config["leadsquared_url"] %>,
  leadsquared_access_key: <%= config["leadsquared_access_key"] %>,
  leadsquared_secret_key: <%= config["leadsquared_secret_key"] %>,
  should_send_sms: <%= config["should_send_sms"] %>,
  default_sms_number: <%= config["default_sms_number"] %>,
  should_send_whatsapp: <%= config["should_send_whatsapp"] %>,
  default_whatsapp_number: <%= config["default_whatsapp_number"] %>,
  whatsapp_token: <%= config["whatsapp_token"] %>,
  builder_chat_min_supported_version: <%= config["builder_chat_min_supported_version"] %>,
  display_project_filters: <%= config["display_project_filters"] %>,
  onground_apis_allowed: <%= config["onground_apis_allowed"] %>,
  rera_validation_url: <%= config["rera_validation_url"] %>,
  piramal_authentication_key: <%= config["piramal_authentication_key"] %>,
  s2c_api_token: <%= config["s2c_api_token"] %>,
  bn_username_in_s2c:  <%= config["bn_username_in_s2c"] %>,
  bn_pwd_in_s2c:  <%= config["bn_pwd_in_s2c"] %>,
  s2c_api_url:  <%= config["s2c_api_url"] %>,
  routed_name:  <%= config["routed_name"] %>,
  piramal_sfdc_url: <%= config["piramal_sfdc_url"] %>,
  salesforce_auth_token_url: <%= config["salesforce_auth_token_url"] %>,
  salesforce_grant_type: <%= config["salesforce_grant_type"] %>,
  salesforce_client_id: <%= config["salesforce_client_id"] %>,
  salesforce_client_secret: <%= config["salesforce_client_secret"] %>,
  piramal_sfdc_username: <%= config["piramal_sfdc_username"] %>,
  piramal_sfdc_password: <%= config["piramal_sfdc_password"] %>,
  hl_manager_phone_number: <%= config["hl_manager_phone_number"] %>,
  youtube_api_key: <%= config["youtube_api_key"] %>,
  youtube_api_base_url: <%= config["youtube_api_base_url"] %>,
  billdesk_redirect_url: <%= config["billdesk_redirect_url"] %>,
  create_order_base_url: <%= config["create_order_base_url"] %>

config :exq,
  name: Exq,
  host: <%= config["redis_host"] %>,
  port: 6379,
  namespace: "bn_apis_exq",
  queues: [
    {"process_post_matches", 2},
    {"matches_notification", 2},
    {"send_notification", 2},
    {"team_notification", 2},
    {"custom_notification", 2},
    {"story", 1},
    {"push_notification", 5},
    {"dnd_removal", 1},
    {"personalised_sales_kit_generator", 20},
    {"broker_kit_generator", 20},
    {"broker_kyc_notification", 2},
    {"homeloan", 2},
    {"leadsquared_lead_push", 2},
    {"slash_lead_push", 2},
    {"send_sms", 2},
    {"send_otp_sms", 2},
    {"payments", 1},
    {"employee_payments", 1},
    {"update_subscription_status", 1},
    {"invoices", 1},
    {"send_owner_notifs", 20},
    {"send_new_project_notifications", 20},
    {"send_new_story_creatives_notifications", 20},
    {"send_transactions_notif", 20},
    {"sendbird", 2},
    {"commercial_sendbird",2},
    {"send_rewards_enabled_notification", 20},
    {"send_changes_requested_fcm_notification",4},
    {"send_whatsapp_message", 20},
    {"reminders", 2},
    {"campaign", 2},
    {"dev_poc_notification_queue", 2},
    {"send_new_invoice_notification", 2},
    {"invoice_payout", 2}
  ],
  poll_timeout: 50,
  scheduler_poll_timeout: 200,
  scheduler_enable: true,
  max_retries: 3,
  shutdown_timeout: 5000,
  start_on_application: false

# Set a higher stacktrace during development. Avoid configuring such
# in production as building large stacktraces may be expensive.
config :phoenix, :stacktrace_depth, 20

# Configure your database
config :bn_apis, BnApis.Repo,
  adapter: Ecto.Adapters.Postgres,
  username: <%= config["db.username"] %>,
  password: <%= config["db.password"] %>,
  database: "bn_apis_production",
  hostname: <%= config["db.host"] %>,
  types: BnApis.PostgresTypes,
  pool_size: 100,
  timeout: 15_000

config :redix,
  host: <%= config["redis_host"] %>,
  port: 6379

config :pigeon, :fcm,
  fcm_default: %{
    key: <%= config["fcm_key"] %>
  }

config :bitly, access_token: <%= config["bitly_access_token"] %>

config :bn_apis, BnApis.IpLoc.API, key: <%= config["ip_loc_key"] %>

{revision, _exitcode} = System.cmd("git", ["log", "--pretty=format:%h", "-n 1"])

config :appsignal, :config,
  otp_app: :bn_apis,
  name: <%= config["appsignal.name"] %>,
  push_api_key: <%= config["appsignal.push_api_key"] %>,
  env: Mix.env,
  revision: revision,
  active: <%= config["appsignal.active"] %>

config :bn_apis, BnApis.Helpers.GoogleMapsHelper,
  autocomplete_url: <%= config["autocomplete_url"] %>

config :bn_payments,
  http_client_opts: [],
  merchant_id: <%= config["bn_payments.merchant_id"] %>,
  client_id: <%= config["bn_payments.client_id"] %>,
  secret_key: <%= config["bn_payments.secret_key"] %>,
  bill_desk_endpoint: <%= config["bn_payments.bill_desk_endpoint"] %>,
  client_module: BnPayments.HttpClient

config :bn_apis, BnApis.Digio.API,
  digio_api_base_url: <%= config["digio_api_base_url"] %>,
  digio_esign_base_url: <%= config["digio_esign_base_url"] %>,
  digio_username: <%= config["digio_username"] %>,
  digio_password: <%= config["digio_password"] %>

config :bn_apis, BnApis.Signzy.API,
  signzy_base_url: <%= config["signzy_base_url"] %>,
  signzy_username: <%= config["signzy_username"] %>,
  signzy_password: <%= config["signzy_password"] %>,
  signzy_callback_url: <%= config["signzy_callback_url"] %>,
  signzy_bn_email_contact: <%= config["signzy_bn_email_contact"] %>
