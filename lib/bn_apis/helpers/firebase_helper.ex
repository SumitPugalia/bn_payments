defmodule BnApis.Helpers.FirebaseHelper do
  alias BnApis.Places.Zone
  alias BnApis.Places.Polygon
  alias BnApis.Helpers.ApplicationHelper
  alias BnApis.Homeloan.Lead
  alias BnApis.Homeloan.Tnc
  alias BnApis.Organizations.BrokerCommission
  alias BnApis.Organizations.Broker
  alias BnApis.AssignedBrokers

  @broker_network_app_name "broker_network"
  @broker_manager_app_name "broker_manager"
  @broker_builder_app_name "broker_builder"

  # @mumbai_city_id 1

  def broker_network_app_name(), do: @broker_network_app_name
  def broker_manager_app_name(), do: @broker_manager_app_name
  def broker_builder_app_name(), do: @broker_builder_app_name

  @transaction_enabled_phone_numbers [
    "9619644823",
    "9318303560",
    "9594954748",
    "9560364888",
    "8007046464",
    "9619198707",
    "8097404157",
    "9167986004",
    "9823259920",
    "7972907629",
    "7011603355",
    "9850036267",
    "7219006333",
    "8879006228",
    "9711227605",
    "9967345427"
  ]

  @match_plus_tnc "<p>These terms of use (\"Terms\") constitute a legally binding agreement between you and 4B Networks Pvt. Ltd (Referred to as the \"Company\" hereinafter) regarding your use of the Broker Network App and any services offered by the Company including but not limited to delivery of content via the Site, any mobile or internet connected device or otherwise (the \"the Service\").</p><br/><p>Your (\“You\” Referred to as \“Subscriber\” hereinafter) use of the mobile App and services and tools are governed by the following Terms as applicable to the Company including the applicable policies which are incorporated herein by way of reference. By mere use of the Site, you shall be contracting with 4B Networks Pvt. Ltd, the Proprietor of the Platform. These terms and conditions including the policies constitute Your binding obligations, with 4B Networks Pvt. Ltd. Below is the list of terms and conditions to be mandatorily followed:</p><br><p>1. All Subscription Charges are due in before commencement of Subscription Term. Subscriber are responsible for providing valid and current payment information and Subscriber agree to promptly update their Account information, including payment information, with any changes that may occur (for example, a change in Your billing address or credit card expiration date).The Subscription charges payable shall be monthly subscription charges.</p><br/><p>2. Company’s services are provided on “as is” basis and Company can\’t guarantee it will be safe and secure or will work perfectly all the time. Company\’s responsibility for anything that happens on the services is limited as much as law will allow. Subscriber agrees that Company shall not be responsible for any lost profits, revenues or data or any consequential, exemplary, punitive, incidental damages arising out of or related to these terms.</p><br/><p>3. Subscribers may cancel their subscription at any time through the Application but the previously paid monthly subscription charges shall not be refundable to Subscribers on cancellation.</p><br/><p>4. The Company shall have exclusive proprietorship rights over the data published on this Application and the Subscribers shall not have right to re-sell the data.</p><br/><p>5. The Company can only assign one account to each subscriber and multiple accounts on one name are prohibited.</p><br/><p>6. The Company shall not be responsible and liable for transactions related to Brokerage payable to concerned brokers by property owners.</p><br/><p>7. The Company reserves its right to revise the Subscription charges any time during subscription by providing an advance notice to subscribers of such change in Subscription charges.</p><br/><p>8. The Company shall not be responsible for the multiple calls received by property owners from subscribers.</p><br/><p>9. On there being a declaration of National or State Lockdown by the Government of India, the Subscriber\’s package shall be extended without any extra charges. The extension of package shall be only for that many number of days subscription charges were paid for and unable to avail because of Lockdown.</p><br/><p>10. The subscriber shall not misuse the company\’s mobile applications for any illegal activity as per current laws of India and Subscribers are prohibited use of any abusive language with property owners. The Company reserves its right to proceed for legal remedies against subscribers in Courts of Mumbai, Maharashtra, India on occurrence of such an activity prohibited by Law.</p><br/><p>11. Company has the right to suspend or delete the accounts of abusive users who violate Company\’s app\’s terms and conditions. Prohibited activities could include copyright infringement, spamming other users, and general misuse of Company\’s app.</p><br/><p>12. Company and Subscriber can choose to settle disputes via arbitration, which can be more efficient and cost-effective than litigation.</p><br/><p>About Us</p><br/><p>Broker Network is one of India’s fastest growing Prop-Tech companies with a revolutionary tech platform that facilitates, enables and empowers brokers and developers. We are a perfect Hybrid of new-age technology and human ingenuity, creating opportunities and efficiencies.</p><br/><p>Broker Network app is a suite of services specifically designed for Indian real estate brokers and developers. At its core, it’s a highly efficient matchmaking platform that connects brokers with properties and brokers with buyers. The match engine works behind the scenes, figures out the perfect match with your post and sends prominent notifications to both parties to connect and make deals. Apart from being automatically connected to the brokers matching your posts in your locality, you will also be able to directly call and chat with thousands of brokers across the network!</p><br/><p>Refund & Cancellation Policy</p><br/><p>Our focus is complete customer satisfaction. In the event, if you are displeased with the services provided, we will refund back the money, provided the reasons are genuine and proved after investigation. Please read the fine prints of each deal before buying it, it provides all the details about the services or the product you purchase.</p><br/><p>In case of dissatisfaction from our services, clients have the liberty to cancel their projects and request a refund from us. Our Policy for the cancellation and refund will be as follows:</p><br/><p>Cancellation Policy</p><br/><p>For Cancellations please contact the us via call support.</p><br/><p>Requests received later then 10 business days prior to the end of the current service period will be treated as cancellation of services for the next service period.</p><br/><p>Privacy Policy</p><br/><p>Our Service offers publicly accessible community services such as help forums. You should be aware that any information you provide in these areas may be read, collected, and used by others who access them. Your posts may remain even after you cancel your account. For questions about your Personal Information on our Service, please contact privacy@brokernetwork.app. Our site includes links to other web sites whose privacy practices may differ from those of BrokerNetwork. If you submit personal information to any of those sites, your information is governed by their privacy statements. We encourage you to carefully read the privacy statement of any web site you visit.</p><br/><p>Contact Us</p><br/><p>Ground Floor, A UNIT OF FLEUR HOTELS PVT LTD, LEMON TREE PREMIER HOTEL, Behind RBL Bank Marol Andheri East, Mumbai, Mumbai Suburban, Maharashtra, 400059 | CIN: U73100MH2020PTC349457</p><br/><p>Tel. No. +912246037832 | www.brokernetwork.app | Email id: contactus@brokernetwork.app (edited)</p>"

  def basic_remote_configs(@broker_network_app_name) do
    %{
      is_paytm_subscription_enabled: ApplicationHelper.get_paytm_subscription_enabled(),
      is_report_button_enabled: false,
      is_personalised_sales_kit_enabled: true,
      show_project_connect: false,
      allow_date_selection_for_rewards: false,
      min_required_projects_for_cabs: 1,
      full_screen_tone_option: "notification",
      keep_live_delay: 31000,
      show_battery_optimization: false,
      show_pull_to_refresh: false,
      is_post_match_number_visible: true,
      match_plus_subscription_update_retry_interval_in_ms: 10000,
      places_key: ApplicationHelper.get_places_key(),
      match_plus_tnc: @match_plus_tnc,
      match_plus_customer_support_number: ApplicationHelper.get_match_plus_customer_support_number(),
      match_plus_pricing: ApplicationHelper.get_match_plus_pricing(),
      contact_support_number: ApplicationHelper.get_customer_support_number(),
      show_incoming_call_modal: false,
      show_call_log_duration_in_profile: false,
      max_building_selection: 5,
      new_launches_title: "New Launches",
      contacts_diff_sync_enabled: false,
      contacts_sync_enabled: false,
      post_card_option_captions: %{
        resale_property: "Resale Property",
        resale_client: "Resale Client",
        rental_property: "Rental Property",
        rental_client: "Rental Client"
      },
      post_option_captions: %{
        resale_property: "I have a Resale Property",
        resale_client: "I have a Resale Client",
        rental_property: "I have a Rental Property",
        rental_client: "I have a Rental Client"
      },
      good_feedback_reasons: %{
        reasons: [
          %{
            name: "Meeting Scheduled",
            id: 5
          },
          %{
            name: "Match was perfect",
            id: 6
          },
          %{
            name: "Broker was excellent",
            id: 7
          },
          %{
            name: "My reason is not listed",
            id: 8
          }
        ],
        name: "Good",
        id: 2
      },
      bad_feedback_reasons: %{
        reasons: [
          %{
            name: "One of more listings had expired",
            id: 1
          },
          %{
            name: "Broker was rude",
            id: 2
          },
          %{
            name: "Broker did not answer",
            id: 3
          },
          %{
            name: "My reason is not listed",
            id: 4
          }
        ],
        name: "Bad",
        id: 1
      },
      report_owner_post_reasons: ApplicationHelper.report_owner_post_reasons(),
      is_transaction_data_enabled: false,
      current_app_version: "103062",
      minimum_supported_version: ApplicationHelper.get_android_minimum_supported_version(@broker_network_app_name),
      ios_minimum_supported_version: ApplicationHelper.get_ios_minimum_supported_version(@broker_network_app_name),
      display_project_filters: ApplicationHelper.display_project_filters(),
      show_commercial_bucket: true,
      show_commercial_bucket_url: true,
      panel_analytics: true,
      apxor: %{
        enable_apxor_sdk: ApplicationHelper.get_enable_apxor_sdk_flag(),
        ios_app_id: ApplicationHelper.get_apxor_ios_app_id(),
        android_app_id: ApplicationHelper.get_apxor_android_app_id()
      }
    }
  end

  def basic_remote_configs(@broker_manager_app_name) do
    %{
      support_number: ApplicationHelper.get_customer_support_number(),
      ios_onground_app_minimum_supported_version: ApplicationHelper.get_ios_minimum_supported_version(@broker_manager_app_name),
      android_onground_app_minimum_supported_version: ApplicationHelper.get_android_minimum_supported_version(@broker_manager_app_name)
    }
  end

  def basic_remote_configs(@broker_builder_app_name) do
    %{
      builder_app_min_supported_version: ApplicationHelper.get_builder_chat_min_supported_version(),
      support_number: ApplicationHelper.get_customer_support_number(),
      ios_builder_app_minimum_supported_version: ApplicationHelper.get_ios_minimum_supported_version(@broker_builder_app_name)
    }
  end

  # user specific logic can be implemented here
  def get_remote_config(nil, app_name), do: basic_remote_configs(app_name)

  def get_remote_config(logged_in_user, @broker_network_app_name) do
    broker_id = logged_in_user[:broker_id]
    broker_type_id = Broker.broker_type_using_broker_id(broker_id)

    {feature_flags, support_phone_number} =
      if broker_type_id == Broker.dsa()["id"] do
        {ApplicationHelper.get_feature_flags_for_dsa(), AssignedBrokers.get_brokers_assigned_employee_number_for_hl(broker_id)}
      else
        {ApplicationHelper.get_feature_flags(logged_in_user[:operating_city]), ApplicationHelper.get_customer_support_number_polygon(logged_in_user[:polygon_uuid])}
      end

    # is_assisted_enabled = check_if_assisted_enabled(logged_in_user[:operating_city], logged_in_user[:polygon_uuid])

    user_specific_configs = %{
      operational_cities: ApplicationHelper.get_operational_cities(),
      razorpay_api_key: ApplicationHelper.get_razorpay_api_key(),
      contact_support_number: support_phone_number,
      is_transaction_data_enabled: logged_in_user[:phone_number] in @transaction_enabled_phone_numbers,
      feature_flags: feature_flags,
      match_plus_packages: ApplicationHelper.get_match_plus_packages(logged_in_user),
      home_loan_notification_count: Lead.hl_notification_count(broker_id)
    }

    user_specific_configs =
      if broker_type_id == Broker.dsa()["id"] do
        Map.merge(user_specific_configs, %{
          "dsa" => %{
            dsa_tnc_data: Tnc.tnc_data(),
            broker_commission_details: BrokerCommission.get_broker_commission_detail(broker_id) |> BrokerCommission.structure_broker_commission_remote_config(),
            hl_tnc_agreed: Broker.get_hl_tnc_agreed(broker_id)
          }
        })
      else
        user_specific_configs
      end

    basic_remote_configs(@broker_network_app_name) |> Map.merge(user_specific_configs)
  end

  def get_remote_config(_logged_in_user, @broker_manager_app_name) do
    user_specific_configs = %{}

    basic_remote_configs(@broker_manager_app_name) |> Map.merge(user_specific_configs)
  end

  # defp check_if_assisted_enabled(@mumbai_city_id, polygon_uuid) do
  #   polygon = Polygon.fetch_from_uuid(polygon_uuid)
  #   zone_allowed = Zone.get_zone_by(%{name: "Mumbai - Thane"})
  #   if is_nil(polygon), do: false, else: polygon.zone_id == zone_allowed.id
  # end

  # defp check_if_assisted_enabled(_city_id, _polygon_uuid), do: false
end
