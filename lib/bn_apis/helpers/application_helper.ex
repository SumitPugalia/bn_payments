defmodule BnApis.Helpers.ApplicationHelper.Behaviour do
  # TODO: Bad practice, move all slack related data to SMS Service module written in other PR.
  @callback send_slack_notification(String.t(), String.t(), list()) :: {integer(), map()}
end

defmodule BnApis.Helpers.ApplicationHelper do
  alias BnApis.Orders.MatchPlusPackage
  alias BnApis.Reasons.ReasonType
  alias BnApis.Reasons.Reason
  alias BnApis.Places.Polygon
  alias BnApis.Places.City
  alias BnApis.Repo
  alias BnApis.Helpers.FirebaseHelper
  alias BnApis.RemoteConfig.RemoteConfig
  alias BnApis.Helpers.ApplicationHelper.Behaviour
  alias BnApis.Orders.MatchPlus
  import Ecto.Query

  @behaviour Behaviour
  @diwali_offer_applied_cities []
  @offer_start_time_epoch 1_666_290_601

  @context_slack_channel_map %{
    "onground_query" => "onground-queries",
    "default" => "default_slack_channel"
  }

  def offer_start_time_epoch(), do: @offer_start_time_epoch
  def diwali_offer_applied_cities(), do: @diwali_offer_applied_cities

  def get_server_env(), do: Application.get_env(:bn_apis, :server_env)

  ## sms related functions
  def get_account_sid(), do: Application.get_env(:bn_apis, :twilio_account_sid)
  def get_auth_token(), do: Application.get_env(:bn_apis, :twilio_auth_token)
  def get_endpoint(), do: Application.get_env(:bn_apis, :twilio_endpoint)
  def sms_from(), do: Application.get_env(:bn_apis, :twilio_from)

  ## bulksms
  def get_bulksms_url(), do: Application.get_env(:bn_apis, :bulksms_url)
  def get_bulksms_api_key(), do: Application.get_env(:bn_apis, :bulksms_apikey)
  def get_bulksms_entity_id(), do: Application.get_env(:bn_apis, :bulksms_entity_id)

  def default_dev_twilio_to(),
    do: Application.get_env(:bn_apis, :default_dev_twilio_to)

  def whitelisted_dev_twilio_tos(),
    do: Application.get_env(:bn_apis, :whitelisted_dev_twilio_tos)

  def sms_token(), do: Application.get_env(:bn_apis, :sms_token)
  def get_env(), do: Mix.env()

  def get_mobtexting_url(),
    do: Application.get_env(:bn_apis, :mobtexting)[:send_endpoint]

  def get_mobtexting_token(),
    do: Application.get_env(:bn_apis, :mobtexting)[:token]

  def is_mobtexting_enabled(),
    do: Application.get_env(:bn_apis, :mobtexting)[:enabled] in ["true", true]

  def get_enable_apxor_sdk_flag(),
    do: Application.get_env(:bn_apis, :apxor)[:enable_apxor_sdk]

  def get_apxor_ios_app_id(),
    do: Application.get_env(:bn_apis, :apxor)[:ios_app_id]

  def get_apxor_android_app_id(),
    do: Application.get_env(:bn_apis, :apxor)[:android_app_id]

  def get_sendbird_application_id(),
    do: Application.get_env(:bn_apis, :sendbird)[:application_id]

  def get_sendbird_api_token(),
    do: Application.get_env(:bn_apis, :sendbird)[:api_token]

  ## s3 related functions
  def get_files_bucket(), do: Application.get_env(:ex_aws, :files_bucket)
  def get_imgix_domain(), do: Application.get_env(:bn_apis, :imgix_domain)
  def get_access_key_id(), do: Application.get_env(:ex_aws, :access_key_id)

  def get_secret_access_key(),
    do: Application.get_env(:ex_aws, :secret_access_key)

  def get_secret_salt(), do: Application.get_env(:bn_apis, :secret_salt)

  ## redis related functions
  def get_redis_host(), do: Application.get_env(:redix, :host)
  def get_redis_port(), do: Application.get_env(:redix, :port)

  ## service related functions
  def get_buffer(), do: 50

  def deep_link_hosted_domain_url(),
    do: Application.get_env(:bn_apis, :deep_link_hosted_domain_url)

  def playstore_app_url(), do: Application.get_env(:bn_apis, :playstore_app_url)

  def bn_web_base_url(), do: Application.get_env(:bn_apis, :bn_web_base_url)

  def deep_link_app_version(),
    do:
      Application.get_env(:bn_apis, :deep_link_app_version)
      |> String.to_integer()

  def hosted_domain_url(), do: Application.get_env(:bn_apis, :hosted_domain_url)
  def generic_notification_type(), do: "GENERIC_NOTIFICATION"

  def get_customer_support_number(),
    do: Application.get_env(:bn_apis, :customer_support_number)

  def get_mumbai_customer_support_number(),
    do: Application.get_env(:bn_apis, :mumbai_customer_support_number)

  def get_match_plus_customer_support_number(),
    do: Application.get_env(:bn_apis, :match_plus_customer_support_number)

  def get_match_plus_price(), do: Application.get_env(:bn_apis, :match_plus_price)

  def get_match_plus_pricing() do
    original_price = Application.get_env(:bn_apis, :match_plus_original_price)
    price = Application.get_env(:bn_apis, :match_plus_price)

    %{
      original_price: original_price,
      price: price,
      offer_applied: original_price != price,
      offer_title: Application.get_env(:bn_apis, :match_plus_offer_title),
      offer_text: Application.get_env(:bn_apis, :match_plus_offer_text)
    }
  end

  def get_match_plus_packages(user), do: MatchPlusPackage.get_data(user)

  def display_project_filters(),
    do: Application.get_env(:bn_apis, :display_project_filters) in ["true", true]

  ## slack related functions
  def get_slack_url(), do: Application.get_env(:bn_apis, :slack_url)
  def get_slack_token(), do: Application.get_env(:bn_apis, :slack_token)
  def get_slack_channel(), do: Application.get_env(:bn_apis, :slack_channel)
  def get_onground_apis_allowed(), do: Application.get_env(:bn_apis, :onground_apis_allowed)

  def get_slack_building_channel(),
    do: Application.get_env(:bn_apis, :slack_building_channel)

  def get_mumbai_customer_support_person(),
    do: Application.get_env(:bn_apis, :mumbai_customer_support_person)

  def get_pune_customer_support_person(),
    do: Application.get_env(:bn_apis, :pune_customer_support_person)

  def get_default_customer_support_person(),
    do: Application.get_env(:bn_apis, :default_customer_support_person)

  ## external services url
  def get_meta_url(), do: Application.get_env(:bn_apis, :meta_service_url)

  ## site visit messages
  def get_broker_message(),
    do: "Your site visit is captured by our team. Contact BrokerNetwork support on #{get_customer_support_number()} to sign up"

  def get_support_team_message(name, phone_number, project_name),
    do: "Unregistered broker #{name} - #{phone_number} visited on project #{project_name}."

  ## IVR related functions
  def get_ivr_url(),
    do: "https://#{get_ivr_sid()}:#{get_ivr_token()}@api.exotel.com/v1/Accounts/#{get_ivr_sid()}/Calls/connect"

  def get_ivr_sid(), do: Application.get_env(:bn_apis, :ivr_sid)
  def get_ivr_token(), do: Application.get_env(:bn_apis, :ivr_token)

  def get_ivr_masked_number(),
    do: Application.get_env(:bn_apis, :ivr_masked_number)

  def get_app_id(), do: Application.get_env(:bn_apis, :ivr_app_id)

  def get_builder_chat_min_supported_version(),
    do: Application.get_env(:bn_apis, :builder_chat_min_supported_version)

  def get_ivr_data_url(),
    do: "http://my.exotel.com/Exotel/exoml/start_voice/#{get_app_id()}"

  def get_dnd_url(),
    do: "https://#{get_ivr_sid()}:#{get_ivr_token()}@api.exotel.com/v1/Accounts/#{get_ivr_sid()}/CustomerWhitelist"

  def get_virtual_number(), do: Application.get_env(:bn_apis, :virtual_number)

  ## places related functions
  def get_places_url(),
    do: "https://maps.googleapis.com/maps/api/place/details/json"

  def get_places_prediction_url(),
    do: "https://maps.googleapis.com/maps/api/place/autocomplete/json"

  def get_reverse_geocode_api_url(),
    do: "https://maps.googleapis.com/maps/api/geocode/json"

  def get_places_key(), do: Application.get_env(:bn_apis, :places_key)

  def filter_place_types(),
    do: [
      "clothing_store",
      "store",
      "university",
      "hospital",
      "secondary_school",
      "school",
      "travel_agency",
      "bakery",
      "food",
      "bar",
      "restaurant",
      "park",
      "police",
      "shopping_mall",
      "hospital",
      "bank",
      "laundry",
      "courthouse",
      "church",
      "place_of_worship",
      "hindu_temple",
      "health",
      "pharmacy",
      "night_club",
      "physiotherapist",
      "gym",
      "fire_station",
      "hair_care"
    ]

  ## DB Query key
  def db_query_key(), do: Application.get_env(:bn_apis, :db_query_key)

  ## polygon related functions

  def get_mumbai_city_id(), do: 1
  def get_pune_city_id(), do: 37

  def get_leadsquared_url(), do: Application.get_env(:bn_apis, :leadsquared_url)
  def get_leadsquared_access_key(), do: Application.get_env(:bn_apis, :leadsquared_access_key)
  def get_leadsquared_secret_key(), do: Application.get_env(:bn_apis, :leadsquared_secret_key)
  def get_should_send_sms(), do: Application.get_env(:bn_apis, :should_send_sms)
  def get_default_sms_number(), do: Application.get_env(:bn_apis, :default_sms_number)
  def get_should_send_whatsapp(), do: Application.get_env(:bn_apis, :should_send_whatsapp)
  def get_default_whatsapp_number(), do: Application.get_env(:bn_apis, :default_whatsapp_number)
  def get_whatsapp_token(), do: Application.get_env(:bn_apis, :whatsapp_token)

  def get_razorpay_url(), do: Application.get_env(:bn_apis, :razorpay_url)

  def get_razorpay_ifsc_url(), do: Application.get_env(:bn_apis, :razorpay_ifsc_url)

  def get_razorpay_match_plus_plan_id(), do: Application.get_env(:bn_apis, :razorpay_match_plus_plan_id)

  def get_razorpay_account_number(),
    do: Application.get_env(:bn_apis, :razorpay_account_number)

  def get_razorpay_api_key(),
    do: Application.get_env(:bn_apis, :razorpay_username)

  def get_razorpay_auth_key() do
    username = Application.get_env(:bn_apis, :razorpay_username)
    password = Application.get_env(:bn_apis, :razorpay_password)
    Base.encode64("#{username}:#{password}")
  end

  def get_piramal_authentication_key(), do: Application.get_env(:bn_apis, :piramal_authentication_key)

  def get_salesforce_auth_token_url(), do: Application.get_env(:bn_apis, :salesforce_auth_token_url)

  def get_sales_force_auth_params() do
    %{
      "grant_type" => Application.get_env(:bn_apis, :salesforce_grant_type),
      "client_id" => Application.get_env(:bn_apis, :salesforce_client_id),
      "client_secret" => Application.get_env(:bn_apis, :salesforce_client_secret),
      "username" => Application.get_env(:bn_apis, :piramal_sfdc_username),
      "password" => Application.get_env(:bn_apis, :piramal_sfdc_password)
    }
  end

  def get_piramal_sfdc_url(), do: Application.get_env(:bn_apis, :piramal_sfdc_url)

  def get_razorpay_webhook_secret_key(),
    do: Application.get_env(:bn_apis, :razorpay_webhook_secret_key)

  def get_bn_apis_base_url(), do: Application.get_env(:bn_apis, :bn_apis_base_url)
  def get_paytm_url(), do: Application.get_env(:bn_apis, :paytm_url)
  def get_paytm_website_mode(), do: Application.get_env(:bn_apis, :paytm_website_mode)
  def get_paytm_merchant_key(), do: Application.get_env(:bn_apis, :paytm_merchant_key)
  def get_paytm_merchant_id(), do: Application.get_env(:bn_apis, :paytm_merchant_id)
  def get_paytm_subscription_amount(), do: Application.get_env(:bn_apis, :paytm_subscription_amount)
  def get_paytm_subscription_validity_in_days(), do: Application.get_env(:bn_apis, :paytm_subscription_validity_in_days)
  def get_paytm_subscription_frequency_unit(), do: Application.get_env(:bn_apis, :paytm_subscription_frequency_unit)
  def get_paytm_subscription_enabled(), do: Application.get_env(:bn_apis, :paytm_subscription_enabled) == true

  def get_slash_url(), do: Application.get_env(:bn_apis, :slash_url)
  def get_slash_username(), do: Application.get_env(:bn_apis, :slash_username)
  def get_slash_password(), do: Application.get_env(:bn_apis, :slash_password)

  def get_hl_manager_phone_number(), do: Application.get_env(:bn_apis, :hl_manager_phone_number)

  def get_attestr_auth_key(),
    do: Application.get_env(:bn_apis, :attestr_auth_key)

  def get_attestr_url(), do: Application.get_env(:bn_apis, :attestr_url)
  def get_attestr_gstin_url(), do: Application.get_env(:bn_apis, :attestr_gstin_url)
  def get_attestr_pan_url(), do: Application.get_env(:bn_apis, :attestr_pan_url)

  def get_ios_minimum_supported_version(app_name) do
    remote_config = Repo.get_by(RemoteConfig, app_name: app_name)

    if not is_nil(remote_config) do
      remote_config.ios_minimum_supported_version
    else
      cond do
        app_name == FirebaseHelper.broker_network_app_name() -> "1.6.42"
        app_name == FirebaseHelper.broker_manager_app_name() -> "1.0.0"
        app_name == FirebaseHelper.broker_builder_app_name() -> "1.0.0"
      end
    end
  end

  def get_android_minimum_supported_version(app_name) do
    remote_config = Repo.get_by(RemoteConfig, app_name: app_name)

    if not is_nil(remote_config) do
      remote_config.android_minimum_supported_version
    else
      cond do
        app_name == FirebaseHelper.broker_network_app_name() -> "200023006"
        app_name == FirebaseHelper.broker_manager_app_name() -> "2000002020"
      end
    end
  end

  def update_remote_config(params, app_name) do
    RemoteConfig.create_or_update_remote_config(params, app_name)
  end

  def get_city_id_from_name(name) do
    city = City |> where([c], fragment("LOWER(?) = Lower(?)", c.name, ^name)) |> Repo.one()

    if not is_nil(city) do
      city.id
    end
  end

  def get_city_name_from_id(id) do
    case id do
      1 -> "Mumbai"
      _ -> "Pune"
    end
  end

  def get_operational_cities() do
    City
    |> select([c], %{
      id: c.id,
      name: c.name,
      feature_flags: c.feature_flags,
      sw_lat: c.sw_lat,
      sw_lng: c.sw_lng,
      ne_lat: c.ne_lat,
      ne_lng: c.ne_lng
    })
    |> Repo.all()
  end

  def get_feature_flags(operating_city) do
    if is_nil(operating_city) do
      %{}
    else
      city = City |> Repo.get_by(id: operating_city)

      case city do
        nil -> %{}
        _ -> city.feature_flags
      end
    end
  end

  def get_feature_flags_for_dsa() do
    %{
      "home_loans" => true,
      "owners" => false,
      "subscriptions" => false,
      "booking_rewards" => false,
      "invoice" => true,
      "transactions" => false,
      "cabs" => false,
      "commercial" => false,
      "matches" => false
    }
  end

  def get_customer_support_number(operating_city) do
    case operating_city do
      # Mumbai City
      1 -> get_mumbai_customer_support_number()
      # Pune City
      37 -> get_customer_support_number()
      _ -> get_customer_support_number()
    end
  end

  def get_customer_support_slack_person(operating_city) do
    case operating_city do
      1 -> get_mumbai_customer_support_person()
      37 -> get_pune_customer_support_person()
      _ -> get_default_customer_support_person()
    end
  end

  def get_customer_support_number_polygon(polygon_uuid) do
    Repo.one(
      from(p in Polygon,
        where: p.uuid == ^polygon_uuid,
        select: p.support_number
      )
    )
  end

  def report_owner_post_reasons() do
    Reason.get_reasons_by_type(ReasonType.report_owner_post().id)
  end

  def post_message_on_slack_channel(text, context, attachments \\ []) do
    channel = @context_slack_channel_map[context]

    if not is_nil(channel) do
      notify_on_slack(text, channel, attachments)
    else
      notify_on_slack(text, @context_slack_channel_map["default"], attachments)
    end
  end

  def notify_on_slack(text, channel, attachments \\ []) do
    config().send_slack_notification(text, channel, attachments)
  end

  @impl Behaviour
  def send_slack_notification(text, channel, attachments) do
    slack_url = get_slack_url()
    token = get_slack_token()

    request = %{
      text: text,
      channel: channel,
      attachments: attachments
    }

    headers = [{"Authorization", "Bearer #{token}"}]

    BnApis.Helpers.ExternalApiHelper.perform(
      :post,
      slack_url,
      request,
      headers,
      [],
      false
    )
  end

  def strip_chars(str, chars) do
    String.replace(str, ~r/[#{chars}]/, "")
  end

  def format_match_plus(match_plus, match_plus_membership, user_package, city_id) do
    allow_extension = if city_id in @diwali_offer_applied_cities and is_nil(match_plus["allow_extension"]), do: true, else: match_plus["allow_extension"]
    display_offer_banner = if city_id in @diwali_offer_applied_cities and is_nil(match_plus["display_offer_banner"]), do: true, else: match_plus["display_offer_banner"]

    data = %{
      "is_match_plus_active" => match_plus_membership["is_match_plus_active"] || user_package["is_match_plus_active"] || match_plus["is_match_plus_active"],
      "package" => %{
        "billing_start_at" => match_plus["billing_start_at"],
        "billing_end_at" => match_plus["billing_end_at"],
        "billing_end_at_in_days" => match_plus["billing_end_at_in_days"],
        "allow_extension" => allow_extension,
        "next_billing_start_at" => match_plus["next_billing_start_at"],
        "next_billing_end_at" => match_plus["next_billing_end_at"],
        "order_id" => match_plus["order_id"],
        "razorpay_order_id" => match_plus["razorpay_order_id"],
        "pg_order_id" => match_plus["pg_order_id"],
        "payment_gateway" => match_plus["payment_gateway"],
        "order_is_client_side_payment_successful" => match_plus["order_is_client_side_payment_successful"],
        "order_status" => match_plus["order_status"],
        "order_created_at" => match_plus["order_created_at"],
        "latest_paid_order_for_number_of_months" => match_plus["latest_paid_order_for_number_of_months"],
        "has_latest_paid_order" => match_plus["has_latest_paid_order"],
        "latest_paid_order_package" => match_plus["latest_paid_order_package"]
      },
      "subscription" => %{
        "billing_start_at" => match_plus_membership["billing_start_at"],
        "billing_end_at" => match_plus_membership["billing_end_at"],
        "billing_end_at_in_days" => match_plus_membership["billing_end_at_in_days"],
        "next_billing_start_at" => match_plus_membership["next_billing_start_at"],
        "next_billing_end_at" => match_plus_membership["next_billing_end_at"],
        "subscription_id" => match_plus_membership["subscription_id"],
        "paytm_subscription_id" => match_plus_membership["paytm_subscription_id"],
        "is_subscription_active" => match_plus_membership["is_match_plus_active"],
        "subscription_is_client_side_payment_successful" => match_plus_membership["subscription_is_client_side_payment_successful"],
        "subscription_status" => match_plus_membership["subscription_status"],
        "subscription_created_at" => match_plus_membership["subscription_created_at"],
        "latest_paid_subscription_package" => match_plus_membership["latest_paid_subscription_package"]
      },
      "user_package" => %{
        "billing_start_at" => user_package["billing_start_at"],
        "billing_end_at" => user_package["billing_end_at"],
        "billing_end_at_in_days" => user_package["billing_end_at_in_days"],
        "allow_extension" => allow_extension,
        "next_billing_start_at" => user_package["next_billing_start_at"],
        "next_billing_end_at" => user_package["next_billing_end_at"],
        "order_id" => user_package["order_id"],
        "razorpay_order_id" => user_package["razorpay_order_id"],
        "pg_order_id" => user_package["pg_order_id"],
        "payment_gateway" => user_package["payment_gateway"],
        "order_is_client_side_payment_successful" => user_package["order_is_client_side_payment_successful"],
        "order_status" => user_package["order_status"],
        "order_created_at" => user_package["order_created_at"],
        "latest_paid_order_for_number_of_months" => user_package["latest_paid_order_for_number_of_months"],
        "has_latest_paid_order" => user_package["has_latest_paid_order"],
        "latest_paid_order_package" => user_package["latest_paid_order_package"],
        "subscription_status" => user_package["subscription_status"]
      }
    }

    match_plus = MatchPlus.get_latest_match_plus(match_plus, user_package)

    mode =
      cond do
        match_plus["is_match_plus_active"] -> match_plus["mode"]
        true -> match_plus_membership["mode"]
      end

    banner_data =
      cond do
        match_plus["is_match_plus_active"] == true or match_plus_membership["is_match_plus_active"] == true ->
          # or (match_plus["is_match_plus_active"] == false and match_plus_membership["is_match_plus_active"] == false) ->
          # For unsubscribed brokers, reverted the offer to see the renewal banner
          %{
            "display_renewal_banner" => false,
            "banner_text" => match_plus["banner_text"],
            "banner_button_text" => match_plus["banner_button_text"],
            "banner_color" => match_plus["banner_color"],
            "display_offer_banner" => display_offer_banner,
            "offer_text" => "*Valid Until 31st Oct"
          }

        match_plus_membership["special_offer"] == true ->
          %{
            "display_renewal_banner" => match_plus_membership["display_renewal_banner"],
            "banner_text" => match_plus_membership["banner_text"],
            "banner_button_text" => match_plus_membership["banner_button_text"],
            "banner_color" => match_plus_membership["banner_color"]
          }

        true ->
          %{
            "display_renewal_banner" => match_plus["display_renewal_banner"],
            "banner_text" => match_plus["banner_text"],
            "banner_button_text" => match_plus["banner_button_text"],
            "banner_color" => match_plus["banner_color"]
          }
      end

    Map.merge(data, %{"banner" => banner_data, "mode" => mode})
  end

  def get_google_maps_helper_module(), do: Application.get_env(:bn_apis, :google_maps_helper_module, BnApis.Helpers.GoogleMapsHelper)

  def get_rera_validation_url(), do: Application.get_env(:bn_apis, :rera_validation_url)

  defp config do
    :bn_apis
    |> Application.get_env(__MODULE__, [])
    |> Keyword.get(:slack_message, __MODULE__)
  end
end
