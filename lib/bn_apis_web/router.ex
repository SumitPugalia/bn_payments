defmodule BnApisWeb.Router do
  use BnApisWeb, :router
  import ExqUIWeb.Router

  pipeline :browser do
    plug(:accepts, ["html"])
    plug(:fetch_session)
    plug(:fetch_flash)
    plug :fetch_live_flash
    plug :put_root_layout, {BnApisWeb.LayoutView, :root}
    plug(:protect_from_forgery)
    plug(:put_secure_browser_headers)
  end

  pipeline :browserwithoutcsrf do
    plug(:accepts, ["html"])
    plug(:fetch_session)
    plug(:fetch_flash)
    plug :fetch_live_flash
    plug :put_root_layout, {BnApisWeb.LayoutView, :root}
    plug(:put_secure_browser_headers)
  end

  pipeline :session_api do
    plug(:accepts, ["json"])
    plug(BnApisWeb.Plugs.SessionPlug)
    plug(BnApisWeb.Plugs.CustomLogger)
  end

  pipeline :on_ground_session_api do
    plug(:accepts, ["json"])
    plug(BnApisWeb.Plugs.CustomCORSPlug)
    plug(BnApisWeb.Plugs.OngroundSessionPlug)
    plug(BnApisWeb.Plugs.CustomLogger)
  end

  pipeline :admin_session_api do
    plug(:accepts, ["json"])
    plug(BnApisWeb.Plugs.CustomCORSPlug)
    plug(BnApisWeb.Plugs.SessionPlug)
    plug(BnApisWeb.Plugs.NotificationAdminPlug)
    plug(BnApisWeb.Plugs.CustomLogger)
  end

  pipeline :legal_entity_poc_api do
    plug(:accepts, ["json"])
    plug(BnApisWeb.Plugs.CustomCORSPlug)
    plug(BnApisWeb.Plugs.LegalEntityPocSession)
    plug(BnApisWeb.Plugs.CustomLogger)
  end

  pipeline :prl_session_api do
    plug(:accepts, ["json"])
    plug(BnApisWeb.Plugs.CustomCORSPlug)
    plug(BnApisWeb.Plugs.PiramalSessionPlug)
  end

  pipeline :developer_session_api do
    plug(:accepts, ["json"])
    plug(BnApisWeb.Plugs.DeveloperSessionPlug)
  end

  pipeline :developer_poc_session_api do
    plug(:accepts, ["json"])
    plug(BnApisWeb.Plugs.DeveloperPocSessionPlug)
  end

  pipeline :internal_session_api do
    plug(:accepts, ["json"])
    plug(BnApisWeb.Plugs.CustomCORSPlug)
    # plug BnApisWeb.Plugs.InternalSessionPlug
  end

  pipeline :api do
    plug(:accepts, ["json"])
    plug(BnApisWeb.Plugs.CustomCORSPlug)
    plug(BnApisWeb.Plugs.CustomLogger)
  end

  pipeline :mix_session_api do
    plug(:accepts, ["json"])
    plug(BnApisWeb.Plugs.CustomCORSPlug)
    plug(BnApisWeb.Plugs.BrokerMixAuthPlug)
  end

  pipeline :xml_passthrough do
    plug :accepts, ["xml"]
    plug Plug.Parsers.XML
  end

  scope "/bn_exq_ui", ExqUi do
    live_exq_ui("/exq")
  end

  scope "/hl", BnApisWeb do
    pipe_through(:browser)
    get("/:homeloan_external_link", V1.HomeloanController, :mark_consent)
  end

  scope "/", BnApisWeb do
    # Use the default browser stack
    pipe_through(:browser)

    get "/", PageController, :index
    get("/health-check", ServiceController, :health_check)
  end

  scope "/", BnApisWeb do
    pipe_through(:browserwithoutcsrf)

    post "/billdesk/return_url", BilldeskController, :return_url
  end

  # Enables LiveDashboard only for development
  #
  # If you want to use the LiveDashboard in production, you should put
  # it behind authentication and allow only admins to access it.
  # If your application does not have an admins-only section yet,
  # you can use Plug.BasicAuth to set up some basic authentication
  # as long as you are also using SSL (which you should anyway).
  if Mix.env() in [:dev, :test] do
    import Phoenix.LiveDashboard.Router

    scope "/" do
      pipe_through :browser
      live_dashboard "/dashboard", metrics: BnApisWeb.Telemetry
    end
  end

  scope "/", BnApisWeb do
    pipe_through(:api)

    post("/query", PanelController, :query)
    post("/whatsapp/webhook", WhatsappController, :process_webhook)
    post("/digio/webhook", DigioController, :process_webhook)
    post("/billdesk/webhook", BilldeskController, :webhook)
  end

  scope "/call", BnApisWeb do
    # will only accept xml in body
    pipe_through(:xml_passthrough)

    # Simple2call webhook apis
    post("/s2c/inbound/get-number", CallController, :get_number_to_connect)
    post("/s2c/save-call-details", CallController, :save_call_details)
  end

  scope "/api", BnApisWeb do
    pipe_through(:mix_session_api)
    get("/maps_search/place_info", MapsSearchController, :fetch_place_details)
    post("/polygons/locality_search", PolygonController, :search_for_broker)

    scope "/v1", V1 do
      get("/generate_token", CommonController, :generate_random_token)
    end
  end

  # Other scopes may use custom stacks.
  scope "/api", BnApisWeb do
    pipe_through(:api)

    scope "/v1", V1, as: :v1 do
      post("/packages/retry_payment", PackagesController, :retry_user_order)
      get("/packages/orders/:order_id", PackagesController, :fetch_user_order)
      get("/packages/orders/:order_id/status", PackagesController, :fetch_user_order_status)
      post("/send_otp", CredentialController, :send_otp)
      post("/resend_otp", CredentialController, :resend_otp)
      post("/verify_otp", CredentialController, :verify_otp)
      post("/signup", CredentialController, :signup)

      get("/homeloan/countries", HomeloanController, :get_countries)
      post("/homeloan/lead_squared_webhook", HomeloanController, :lead_squared_webhook)
      post("/razorpay_webhooks", RewardsController, :razorpay_webhook)
      post("/razorpay_webhooks/all", WebhooksController, :generic_razorpay_webhook)
      post("/paytm_webhooks/", WebhooksController, :paytm_webhook)
      post("/lead/webhook", WebhooksController, :lead_webhook)
      post("/lead/webhook/propcatalyst", WebhooksController, :lead_propcatalyst_webhook)
      post("/raw_lead/webhook/fb", WebhooksController, :raw_lead_fb_webhook)
      get("/list_cities_with_owner_subscription", CityController, :list_cities_with_owner_subscription)
    end

    scope "/v2", V2, as: :v2 do
      post("/verify_otp", CredentialController, :verify_otp)
    end

    scope "/terms-of-use" do
      pipe_through(:browser)
      get("/:alpha2", LocalizationController, :terms_of_use)
    end

    get("/stories/template", StoryController, :get_template)
    get("/get_ivr_text", CredentialController, :get_text)
    get("/base_remote_config", FirebaseController, :base_remote_config)
    post("/send_otp", CredentialController, :send_otp)
    post("/resend_otp", CredentialController, :resend_otp)
    post("/verify_otp", CredentialController, :verify_otp)
    post("/signup", CredentialController, :signup)

    get("/protected_signed_url", S3Controller, :protected_signed_url)
    # Polygon apis
    get("/:type/predict", PolygonController, :predict_polygon)
    get("/polygons/search", PolygonController, :search)
    get("/cities", PolygonController, :get_cities_list)

    # CHAT AUTHENTICATE
    post("/chat/authenticate", CredentialController, :authenticate_chat_token)

    # Twilio SMS Webhook
    post("/sms/message_status_webhook", SmsController, :message_status_webhook)

    post("/notifications/update_status", NotificationController, :update_status)

    # mobtexting SMS Webhook
    get(
      "/mobtexting/sms/message_status_webhook",
      SmsController,
      :mobtexting_message_status_webhook
    )
  end

  scope "/api", BnApisWeb do
    pipe_through(:session_api)

    # temp fix: this will work for admin token only
    get("/organizations/filter", OrganizationController, :filter_organizations)

    scope "/v1", V1, as: :v1 do
      post("/validate", CredentialController, :validate)
      get("/buildings/search", BuildingController, :search_buildings)

      get(
        "/buildings/landmark_suggestions",
        BuildingController,
        :landmark_suggestions
      )

      get("/generate_token", CommonController, :generate_random_token)

      post(
        "/buildings/building_suggestions",
        BuildingController,
        :building_suggestions
      )

      post("/posts/:post_type/:post_sub_type", PostController, :create_post)
      get("/matches_home", DashboardController, :matches_home)

      get(
        "/posts/:post_type/:post_sub_type/:post_uuid/matches",
        PostController,
        :post_matches
      )

      post("/posts/owner", PostController, :fetch_owner_posts)
      get("/posts/owner/shortlisted", PostController, :fetch_shortlisted_owner_posts)
      post("/posts/:post_type/property/owner/:post_uuid/shortlist", PostController, :shortlist_owner_post)
      post("/posts/:post_type/property/owner/:post_uuid/contacted", PostController, :mark_owner_post_contacted)
      get("/posts/:post_type/property/owner/:post_uuid/shareable_url", PostController, :generate_shareable_post_image_url)
      get("/posts/expired", PostController, :fetch_expired_posts)
      get("/posts/unread_expired", PostController, :fetch_unread_expired_posts)

      get(
        "/posts/unread_expired_count",
        PostController,
        :fetch_unread_expired_posts_count
      )

      post(
        "/posts/mark_all_expired_as_read",
        PostController,
        :mark_all_expired_as_read
      )

      post(
        "/posts/:post_type/:post_sub_type/:post_uuid/report_post",
        PostController,
        :report_post
      )

      get(
        "/posts/:post_type/property/owner/:post_uuid/fetch_all_similar_posts",
        PostController,
        :list_similar_posts
      )

      get("/posts/team", PostController, :team_posts)

      get("/homeloan/leads", HomeloanController, :get_leads)
      get("/homeloan/lead/:lead_id", HomeloanController, :get_lead_data)
      post("/homeloan/leads", HomeloanController, :create_lead)
      patch("/homeloan/leads/:id", HomeloanController, :update_lead)
      post("/homeloan/leads/upload_document", HomeloanController, :broker_upload_document)
      post("/homeloan/leads/delete_document", HomeloanController, :broker_delete_document)
      get("/homeloan/leads/documents", HomeloanController, :broker_get_documents)
      get("/homeloan/leads/doc_types", HomeloanController, :get_doc_types)
      patch("/homeloan/status/mark_seen", HomeloanController, :mark_seen)
      post("/homeloan/tnc/mark-read", HomeloanController, :mark_tnc_read)
      post("/homeloan/leads/validate-pan", HomeloanController, :validate_pan)
      post("/homeloan/add-loan-disbursement", HomeloanController, :add_homeloan_disbursement_from_app)
      patch("/homeloan/edit-disbursement/:id", HomeloanController, :edit_homeloan_disbursement_from_app)
      patch("/homeloan/delete-disbursement/:id", HomeloanController, :delete_homeloan_disbursement_from_app)

      post(
        "/homeloan/update_lead_status",
        HomeloanController,
        :update_lead_status_for_dsa
      )

      # Loan file App APIs
      post("/homeloan/create-loan-file", HomeloanController, :create_loan_file)
      patch("/homeloan/:loan_file_id/update-loan-file", HomeloanController, :update_loan_file)

      get("/rewards/leads", RewardsController, :get_leads)
      get("/rewards/draft/leads", RewardsController, :get_draft_leads)
      post("/rewards/leads", RewardsController, :create_lead)
      post("/rewards/lead/:id", RewardsController, :update_lead)
      post("/rewards/lead/delete/:id", RewardsController, :delete_lead)

      get("/cabs/meta", CabsController, :meta)
      post("/cabs/requests", CabsController, :create_booking_request)
      post("/cabs/requests/:id", CabsController, :update_booking_request)
      post("/cabs/requests/delete/:id", CabsController, :delete_booking_request)
      get("/cabs/requests", CabsController, :get_all_booking_requests_for_broker)

      # Subscription APIs
      get("/subscriptions/history", SubscriptionsController, :get_subscriptions_history)
      post("/subscriptions", SubscriptionsController, :create_subscription)
      post("/subscriptions/:id/mark_as_registered", SubscriptionsController, :mark_subscription_as_registered)
      post("/subscriptions/:id/update", SubscriptionsController, :update_subscription)
      post("/subscriptions/:id/cancel", SubscriptionsController, :cancel_subscription)

      # Order APIs
      get("/orders/history", OrdersController, :get_orders_history)
      post("/orders", OrdersController, :create_order)
      post("/orders/:id/mark_as_paid", OrdersController, :mark_order_as_paid)
      post("/orders/:id/update", OrdersController, :update_order)
      post("/orders/:id/update-gst", OrdersController, :update_gst)

      # Packages APIs
      post("/packages/create", PackagesController, :create_user_order)
      post("/packages/:package_uuid/cancel", PackagesController, :cancel)
      get("/packages/history", PackagesController, :get_packages_history)
      post("/packages/orders/:id/update-gst", PackagesController, :update_gst)

      # commercials api
      post("/commercial/post/all", CommercialController, :list_post)
      get("/commercial/post/:post_uuid/get", CommercialController, :get_post)
      get("/commercial/fetch_shortlisted", CommercialController, :fetch_all_shortlisted_posts)
      get("/commercial/visits/all", CommercialController, :list_site_visits_for_broker)
      post("/commercial/visit/create", CommercialController, :create_site_visit)
      patch("/commercial/visit/update/:visit_id", CommercialController, :update_site_visit)
      patch("/commercial/visit/delete/:visit_id", CommercialController, :delete_site_visit)

      # Story APIs
      get("/stories", StoryController, :fetch_all_stories)
      get("/stories/filters_metadata", StoryController, :filters_metadata)
      get("/stories/favourites", StoryController, :fetch_all_favourite_stories)
      get("/stories/:story_uuid/fetch", StoryController, :show)
      get("/stories/search", StoryController, :search)

      # Buckets APIs
      scope "/posts", Posts do
        post("/buckets", BucketController, :create)
        get("/buckets", BucketController, :index)
        get("/buckets/:bucket_id", BucketController, :bucket_details)
        patch("/buckets/:bucket_id", BucketController, :update)
      end

      # Booking reward APIs
      post("/booking_reward", BookingRewardsController, :create_booking_rewards_lead)
      patch("/booking_reward/:uuid", BookingRewardsController, :update_booking_rewards_lead)
      post("/booking_reward/:uuid", BookingRewardsController, :delete_booking_rewards_lead)
      get("/booking_reward/:uuid", BookingRewardsController, :fetch_booking_rewards_lead)
      get("/booking_reward", BookingRewardsController, :get_brokers_booking_rewards_leads)
      get("/booking_reward/:uuid/get-invoice-prefill", BookingRewardsController, :get_prefill_invoice_details)
      post("/booking_reward/:uuid/save-invoice-details", BookingRewardsController, :update_invoice_details)

      post("/meetings/qr-code", MeetingController, :save_lat_long_and_generate_qr)

      ## Billing Company APIs
      post("/billing_companies", BillingCompanyController, :create_billing_company)
    end

    scope "/v2", V2, as: :v2 do
      post("/validate", CredentialController, :validate)
      get("/matches_home", DashboardController, :matches_home)

      get(
        "/posts/:post_type/:post_sub_type/:post_uuid/matches",
        PostController,
        :post_matches
      )

      get("/posts/:post_type/property/owner/:post_uuid/contacted", PostController, :mark_contacted_and_fetch_counts)

      get("/rewards/leads", RewardsController, :get_leads)

      # post("/subscriptions", SubscriptionsController, :create_membership)
      # post("/subscriptions/:id/mark_as_registered", SubscriptionsController, :mark_membership_as_registered)
      # post("/subscriptions/:id/update", SubscriptionsController, :update_membership)
      post("/subscriptions/:id/cancel", SubscriptionsController, :cancel_membership)
      get("/subscriptions/:id", SubscriptionsController, :fetch_membership_details)

      get(
        "/subscriptions/:id/fetch_paytm_subscription_details",
        SubscriptionsController,
        :fetch_paytm_subscription_details
      )

      get("/subscriptions/transactions/history", SubscriptionsController, :fetch_transaction_history)
      post("/subscriptions/orders/:membership_order_id/update-gst", SubscriptionsController, :update_gst)

      get("/homeloan/leads", HomeloanController, :get_leads)
      get("/homeloan/lead/:lead_id", HomeloanController, :get_lead_data)
      # post api for adding filters which needs to sent in body
      post("/homeloan/filter-leads", HomeloanController, :get_leads)
    end

    scope "/campaign" do
      post("/update/stats", CampaignController, :update_campaign_stats)
      get("/latest-active", CampaignController, :active_campaign)
      post("/adani/create_pass", CampaignController, :create_pass)
      post("/adani/verify_pass_otp", CampaignController, :verify_pass_otp)
    end

    post("/call/brokers/connect", CallController, :connect_call)

    get("/remote_config", FirebaseController, :remote_config)
    get("/login_config", LocalizationController, :login_metadata)

    post("/signout", CredentialController, :signout)
    post("/validate", CredentialController, :validate)

    post("/credentials/fcm_id", CredentialController, :update_fcm_id)
    post("/credentials/apns_id", CredentialController, :update_apns_id)

    post("/credentials/upi_id", CredentialController, :update_upi_id)
    get("/credentials/check_upi", CredentialController, :check_upi)
    post("/credentials/validate_upi", CredentialController, :validate_upi_id)
    post("/credentials/validate_gstin", CredentialController, :validate_gstin)

    post("/brokers/profile", BrokerController, :update_profile)
    get("/brokers/profile", BrokerController, :get_profile_details)
    post("/brokers/profile_pic", BrokerController, :update_profile_pic)
    post("/brokers/pan_pic", BrokerController, :update_pan_pic)
    post("/brokers/rera_file", BrokerController, :update_rera_file)
    post("/brokers/mark_contacted", BrokerController, :mark_contacted)
    post("/brokers/mark_contacted/:post_type/property/:post_uuid/owner", BrokerController, :mark_contacted_owner)
    post("/brokers/broker-kyc", BrokerController, :update_broker_kyc_details)

    # TEAM Management APIS
    get("/team", OrganizationController, :get_team)
    get("/v1/team", V1.OrganizationController, :get_team)
    get("/team/successor", OrganizationController, :successor_list)
    get("/team/details", OrganizationController, :get_team_data)
    post("/invites", OrganizationController, :send_invite)
    post("/invites/:invite_uuid/resend", OrganizationController, :resend_invite)
    post("/invites/:invite_uuid/cancel", OrganizationController, :cancel_invite)

    # Organization Joining Request APIs
    get("/organization/:joining_request_id/joining-request", OrganizationController, :fetch_joining_request)
    get("/organization/broker-pending-requests", OrganizationController, :fetch_pending_joining_requests_for_credential)
    post("/organization/request-to-join", OrganizationController, :create_org_joining_request)
    post("/organization/:joining_request_id/approve-joining-request", OrganizationController, :approve_org_joining_request)
    post("/organization/:joining_request_id/reject-joining-request", OrganizationController, :reject_org_joining_request)
    post("/organization/:joining_request_id/cancel-joining-request", OrganizationController, :cancel_org_joining_request)

    post("/accounts/:user_uuid/promote", CredentialController, :promote_user)
    post("/accounts/:user_uuid/demote", CredentialController, :demote_user)
    post("/accounts/:user_uuid/remove", CredentialController, :remove_user)
    post("/accounts/leave", CredentialController, :leave_user)
    post("/accounts/:user_uuid/block", CredentialController, :block)
    post("/accounts/:user_uuid/unblock", CredentialController, :unblock)

    get("/team/setting", OrganizationController, :get_org_settings)
    post("/team/toggle-billing-company", OrganizationController, :toggle_billing_company_preference)
    post("/team/toggle-upi", OrganizationController, :toggle_team_upi)

    # STORIES APIS
    get("/dashboard", StoryController, :dashboard)
    get("/stories", StoryController, :fetch_all_stories)
    get("/stories/favourites", StoryController, :fetch_all_favourite_stories)
    get("/stories/:story_uuid/fetch", StoryController, :show)
    get("/stories/search", StoryController, :search)
    get("/stories/legal_entity_search", StoryController, :legal_entity_search)
    get("/stories/filters", StoryController, :filter)
    get("/stories/filters_count", StoryController, :filter_count)
    get("/rewards-stories", StoryController, :fetch_rewards_enables_stories)

    get(
      "/stories/sales_kit/:sales_kit_uuid/personalised_document",
      StoryController,
      :sales_kit_document
    )

    post("/stories/:story_uuid/call_log", StoryController, :create_call_log)

    post(
      "/stories/:story_uuid/sections/:section_uuid/mark_seen",
      StoryController,
      :mark_seen
    )

    post(
      "/stories/:story_uuid/mark_favourite",
      StoryController,
      :mark_favourite
    )

    post(
      "/stories/:story_uuid/remove_favourite",
      StoryController,
      :remove_favourite
    )

    patch(
      "/stories/:story_uuid/update_call_flog",
      StoryController,
      :update_call_log
    )

    post("/notifications/slack", PostController, :notify_on_slack)

    # Billing Companies APIs
    get("/billing_companies", BillingCompanyController, :get_billing_companies_for_broker)
    get("/billing_companies/:uuid/fetch", BillingCompanyController, :fetch_billing_company)
    post("/billing_companies", BillingCompanyController, :create_billing_company)
    post("/billing_companies/:uuid/update", BillingCompanyController, :update_billing_company)
    post("/billing_companies/:uuid/delete", BillingCompanyController, :delete_billing_company)

    ## Billing Company - Get Billing Companies for Broker - V1
    get("/v1/billing_companies", BillingCompanyController, :get_billing_companies_for_broker_v1)

    # Invoice APIs
    get("/invoices/meta", InvoiceController, :invoices_meta)
    post("/invoices", InvoiceController, :create_invoice_for_broker)
    get("/invoices/broker/fetch", InvoiceController, :fetch_all_invoice_for_broker)
    get("/invoices/:uuid/fetch", InvoiceController, :fetch_invoice_for_broker_by_uuid)
    post("/invoices/broker/:uuid/update", InvoiceController, :update_invoice_for_broker)
    get("/invoices/:uuid/generate-invoice-pdf", InvoiceController, :generate_invoice_pdf)
    get("/invoices/:invoice_uuid/generate-booking-invoice-pdf", InvoiceController, :create_booking_invoice_pdf)
    post("/invoices/:uuid/delete-invoice", InvoiceController, :delete_invoice)
    patch("/invoices/:uuid/admin_approve-invoice", InvoiceController, :mark_as_approved_by_org_admin)
    patch("/invoices/:uuid/admin_reject-invoice", InvoiceController, :mark_as_rejected_by_org_admin)

    # FORMS APIS
    post("/posts/:post_type/:post_sub_type", PostController, :create_post)

    get("/fetch_form_data", PostController, :fetch_form_data)
    get("/buildings/search", BuildingController, :search_buildings)
    get("/buildings/suggestions", BuildingController, :suggestions)
    get("/buildings/meta_data", BuildingController, :meta_data)

    get(
      "/buildings/landmark_suggestions",
      BuildingController,
      :landmark_suggestions
    )

    # FORMS ACTIONS
    get("/posts", PostController, :fetch_all_posts)
    get("/posts/archived", PostController, :fetch_expired_posts)

    post(
      "/posts/:post_type/:post_sub_type/:post_uuid/archive",
      PostController,
      :archive
    )

    post(
      "/posts/:post_type/:post_sub_type/:post_uuid/refresh",
      PostController,
      :refresh
    )

    post(
      "/posts/:post_type/:post_sub_type/:post_uuid/restore",
      PostController,
      :restore
    )

    post(
      "/posts/:post_type/:post_sub_type/:post_uuid/reassign",
      PostController,
      :reassign
    )

    get(
      "/accounts/:user_uuid/profile_details",
      PostController,
      :profile_details
    )

    # BROKER MATCHES APIS
    get(
      "/posts/:post_type/:post_sub_type/:post_uuid/matches",
      PostController,
      :post_matches
    )

    get(
      "/posts/:post_type/:post_sub_type/:post_uuid/:broker_uuid/more_matches",
      PostController,
      :more_post_matches_with_broker
    )

    get(
      "/posts/:post_type/:post_sub_type/:post_uuid/own_post_matches",
      PostController,
      :own_post_matches
    )

    get(
      "/posts/:broker_uuid/matches_with_broker",
      PostController,
      :matches_with_broker
    )

    get(
      "/posts/:phone_number/outstanding_matches",
      PostController,
      :outstanding_matches
    )

    post(
      "/posts/:post_type/:post_sub_type/:post_uuid/mark_irrelevant",
      PostController,
      :mark_irrelevant
    )

    post(
      "/posts/:post_type/:post_sub_type/:post_uuid/mark_read",
      PostController,
      :mark_read
    )

    post("/posts/mark_read_bulk", PostController, :mark_read_bulk)
    post("/posts/report", PostController, :report_broker)
    post("/posts/mark_irrelevant_bulk", PostController, :mark_irrelevant_bulk)

    # MATCH APIS
    post("/match/update_match_status", MatchController, :update_match_status)

    # CALL LOG APIS
    post(
      "/call_logs/notify_receiver",
      CallLogController,
      :log_and_notify_receiver
    )

    post("/call_logs/:log_uuid/log_end_time", CallLogController, :log_end_time)
    post("/call_logs", CallLogController, :create_call_log)
    get("/call_logs", CallLogController, :get_call_logs)

    # PROJECT CONNECT APIS
    get("/projects/search", ProjectController, :suggest_projects)
    get("/projects/:project_uuid", ProjectController, :project_details)

    post(
      "/projects/sales_persons/:person_uuid/call",
      ProjectController,
      :create_call_log
    )

    get("/projects/sales_persons/call_logs", ProjectController, :get_call_logs)

    # FEEDBACK APIS
    post("/feedbacks", FeedbackController, :create_feedback)
    get("/feedbacks/form_data", FeedbackController, :form_data)

    # EVENTS APIS
    post("/events", EventController, :create)

    # Notification APIS
    get("/notifications/poll", NotificationController, :poll)

    post("/users_contacts/bulk_sync", UserContactController, :bulk_sync)
    resources("/users_contacts", UserContactController, except: [:new, :edit])

    get("/reasons", ReasonController, :index)

    get("/localities/search", LocalityController, :search_localities)
    get("/localities", LocalityController, :index)

    get(
      "/transactions/search_buildings",
      TransactionController,
      :search_buildings
    )

    get(
      "/transactions/get_transactions",
      TransactionController,
      :get_transactions
    )

    get(
      "/transactions/:transaction_data_id/html",
      TransactionController,
      :transaction_html
    )

    get(
      "/feed_transactions",
      FeedTransactionController,
      :index
    )

    get(
      "/entities/search",
      FeedTransactionController,
      :entities_search
    )

    get(
      "/brokers/kit",
      BrokerController,
      :broker_kit
    )

    # Commercials APIS
    post("/commercial/post/all", CommercialController, :list_post)
    get("/commercial/post/:post_uuid/get", CommercialController, :get_post)
    get("/commercial/post/document/:id", CommercialController, :get_document)
    post("/commercial/post/:post_uuid/shortlist", CommercialController, :shortlist_post)
    get("/commercial/fetch_shortlisted", CommercialController, :fetch_all_shortlisted_posts)
    post("/commercial/post/:post_uuid/report", CommercialController, :report_post)
    post("/commercial/post/:post_uuid/contacted", CommercialController, :mark_post_contacted)
    get("/commercial/meta_data", CommercialController, :meta_data)
    post("/commercial/visit/create", CommercialController, :create_site_visit)
    patch("/commercial/visit/update/:visit_id", CommercialController, :update_site_visit)
    patch("/commercial/visit/delete/:visit_id", CommercialController, :delete_site_visit)
    get("/commercial/visits/all", CommercialController, :list_site_visits_for_broker)
    post("/commercial/chat/channel/create", CommercialController, :create_channel_for_broker)

    get("/legal_entity/:uuid/fetch", LegalEntityController, :show)

    post("/commercial/bucket/create", CommercialController, :create_bucket)
    get("/commercial/bucket/get/:id", CommercialController, :get_bucket)
    get("/commercial/bucket/:id/:status_id", CommercialController, :list_bucket_status_post)
    get("/commercial/bucket/all", CommercialController, :list_bucket)
    post("/commercial/bucket/add", CommercialController, :add_or_remove_post_from_bucket)
    patch("/commercial/bucket/delete", CommercialController, :remove_bucket)
    patch("/commercial/bucket/status/delete", CommercialController, :remove_bucket_status)
  end

  # ================= ADMIN ==================

  scope "/admin", BnApisWeb, as: :admin do
    pipe_through(:api)

    post("/raw_posts/:property_type/create", RawPostController, :create)
    post("/raw_posts/:property_type/:uuid/update", RawPostController, :update)
    post("/buildings/open_search", BuildingController, :admin_open_search_buildings)
    post("/send_otp", EmployeeCredentialController, :send_otp)
    post("/resend_otp", EmployeeCredentialController, :resend_otp)
    post("/verify_otp", EmployeeCredentialController, :verify_otp)
    get("/commercial/bucket/view", CommercialController, :mark_bucket_viewed)
    get("/commercial/bucket/get", CommercialController, :get_bucket_details)

    # post "/signup", EmployeeCredentialController, :signup
  end

  scope "/admin", BnApisWeb, as: :admin do
    pipe_through(:admin_session_api)

    post("/reset_otp_limit", EmployeeCredentialController, :reset_otp_limit)
    post("/signout", EmployeeCredentialController, :signout)
    post("/validate", EmployeeCredentialController, :validate)
    post("/whitelist_number", EmployeeCredentialController, :whitelist_number)
    post("/whitelist_broker", EmployeeCredentialController, :whitelist_broker)
    post("/mark_inactive", EmployeeCredentialController, :mark_inactive)
    post("/activate_broker", EmployeeCredentialController, :activate_broker)
    post("/mark_test_user", EmployeeCredentialController, :mark_test_user)
    post("/update_remote_config", FirebaseController, :update_remote_config)
    post("/polygons/locality_search", PolygonController, :search_for_admin)
    get("/fetch_address", MapsSearchController, :fetch_addess)

    post(
      "/update_broker_city",
      EmployeeCredentialController,
      :update_operating_city
    )

    post("/add_employee", EmployeeCredentialController, :add_employee)

    get(
      "/organizations/unassigned",
      EmployeeCredentialController,
      :fetch_unassigned_organizations
    )

    post("/accounts", EmployeeCredentialController, :update_profile)

    post(
      "/accounts/profile_pic",
      EmployeeCredentialController,
      :update_profile_pic
    )

    get("/dashboard", EmployeeCredentialController, :dashboard)
    get("/config", EmployeeCredentialController, :config)
    get("/meta_data", EmployeeCredentialController, :meta_data)
    get("/get_assigned_employee", EmployeeCredentialController, :get_all_assigned_employee)

    # Building APIS
    get("/buildings/search", BuildingController, :admin_search_buildings)
    get("/buildings/:uuid/fetch", BuildingController, :fetch_building)
    post("/buildings", BuildingController, :create_building)
    post("/buildings/all", BuildingController, :admin_list_building)
    patch("/buildings/:uuid", BuildingController, :update_building)
    get("/buildings/meta_data", BuildingController, :meta_data)
    post("/buildings/upload_document", BuildingController, :upload_document)
    patch("/buildings/document/remove", BuildingController, :remove_document)
    post("/buildings/upload_transaction_csv", BuildingController, :upload_building_txn_csv)
    get("/buildings/download_transaction_csv", BuildingController, :download_building_txn_csv)
    get("/buildings/:uuid/transactions", BuildingController, :building_txn)

    # Developer Apis
    get("/developers", DeveloperController, :index)
    get("/developers/:uuid/fetch", DeveloperController, :fetch)
    get("/developers/search", DeveloperController, :search_developers)
    post("/developers", DeveloperController, :create_developer)
    patch("/developers/:uuid", DeveloperController, :update_developer)

    # Employees Related Apis
    post("/employees", EmployeeCredentialController, :create_employee)

    post(
      "/employees/:phone_number/remove",
      EmployeeCredentialController,
      :remove_employee
    )

    post(
      "/employees/assign_brokers",
      EmployeeCredentialController,
      :assign_brokers
    )

    post(
      "/employees/reassign_organization",
      EmployeeCredentialController,
      :reassign_organization
    )

    post(
      "/employees/transfer_organizations",
      EmployeeCredentialController,
      :transfer_organizations
    )

    patch(
      "/employees/assign_brokers",
      EmployeeCredentialController,
      :update_assign_brokers
    )

    get(
      "/employees/:uuid/assigned_brokers",
      EmployeeCredentialController,
      :fetch_assigned_brokers
    )

    get(
      "/employees/:uuid/assigned_organizations",
      EmployeeCredentialController,
      :fetch_assigned_organizations
    )

    get("/employees/all", EmployeeCredentialController, :all_employees)
    get("/employees", EmployeeCredentialController, :get_employees)
    get("/employees/search", EmployeeCredentialController, :search_employees)
    get("/employees/:uuid/fetch", EmployeeCredentialController, :show)
    get("/employees/:uuid/analytics", EmployeeCredentialController, :analytics)

    post("/employees/upi_id", EmployeeCredentialController, :update_upi_id)
    post("/employees/:uuid/update", EmployeeCredentialController, :update_employee_details)
    get("/employees/check_upi", EmployeeCredentialController, :check_upi)
    post("/employees/validate_upi", EmployeeCredentialController, :validate_upi_id)

    # Match Plus Package APIs
    get("/match_plus_package/all", MatchPlusPackageController, :all_match_plus_data)
    get("/match_plus_package/:uuid/fetch", MatchPlusPackageController, :show)
    post("/match_plus_package", MatchPlusPackageController, :create_match_plus_record)
    patch("/match_plus_package/:uuid/update", MatchPlusPackageController, :update_match_plus_record)

    get(
      "/developer-pocs/all",
      DeveloperPocCredentialController,
      :all_developer_pocs
    )

    get(
      "/developer-pocs/search",
      DeveloperPocCredentialController,
      :search_developer_pocs
    )

    post(
      "/developer-pocs/",
      DeveloperPocCredentialController,
      :create_developer_poc
    )

    post(
      "/developer-pocs/:id",
      DeveloperPocCredentialController,
      :update_developer_poc
    )

    # Panel - Broker Related Apis
    post("/brokers/index", BrokerController, :index)
    get("/brokers/all", BrokerController, :all_brokers)
    get("/brokers/:id/fetch", BrokerController, :show)
    post("/brokers/update_broker_type", BrokerController, :update_broker_type)
    post("/brokers/update_broker_info", BrokerController, :update_broker_info)
    post("/brokers/attach_owner_employee", BrokerController, :attach_owner_employee)
    get("/brokers/unassigned_og_employee", BrokerController, :fetch_brokers_with_no_og_employee)

    # dsa related apis
    patch("/brokers/whitelisting/update/:id/:status", BrokerController, :update_broker_status)

    scope "/brokers", Admin do
      post("/:id/mark-kyc-approved", BrokerController, :mark_kyc_as_approved)
      post("/:id/mark-kyc-rejected", BrokerController, :mark_kyc_as_rejected)
    end

    # Whatsapp APIs
    post(
      "/whatsapp/posts/:post_type/:post_sub_type",
      WhatsappController,
      :create_post
    )

    # Stories API
    get("/stories/meta", StoryController, :meta)
    get("/stories", StoryController, :index)
    get("/stories/:story_uuid/fetch", StoryController, :fetch_story)
    get("/stories/search", StoryController, :admin_search)
    post("/stories", StoryController, :create)
    patch("/stories/:story_uuid", StoryController, :update)
    post("/stories/update_topup", StoryController, :update_story_transaction)
    get("/stories/:story_uuid/topup", StoryController, :get_story_transaction)
    post("/stories/:story_uuid/broadcast", StoryController, :broadcast)
    post("/stories/story_tier", StoryController, :create_story_tier)
    get("/protected_signed_url", S3Controller, :protected_signed_url)

    # Stories Tier Plan APIs
    post("/stories/story_tier_plan_mapping", StoryController, :add_story_tier_plan)
    post("/stories/story_tier_plan_mapping/:story_tier_plan_mapping_id", StoryController, :update_story_tier_plan)

    # Transactions Data API
    resources("/transactions_data", TransactionDataController, except: [:new, :edit, :create])

    get("/transactions_districts", TransactionDataController, :list_districts)

    # Polygon APIS
    get("/polygons", PolygonController, :index)
    get("/polygons/search", PolygonController, :search)
    get("/polygons/:uuid", PolygonController, :show)
    post("/polygons", PolygonController, :create)
    patch("/polygons/modify/:uuid", PolygonController, :update)
    get("/polygons/zone/:zone_id", PolygonController, :get_polygons_from_zone_id)
    get("/polygons/city/:city_id", PolygonController, :get_polygons_from_city_id)
    patch("/polygons/add_zone/id", PolygonController, :add_zone_to_polygon_using_id)

    get("/broadcast", SmsController, :broadcast)

    get("/organizations", OrganizationController, :all_organizations)
    get("/organizations/filter", OrganizationController, :filter_organizations)

    get(
      "/organizations/:org_uuid/brokers",
      OrganizationController,
      :fetch_brokers
    )

    get("/buildings/autocomplete", TransactionDataController, :search_buildings)

    get(
      "/fetch_unprocessed_transaction_data",
      TransactionDataController,
      :fetch_unprocessed_transaction_data
    )

    post(
      "/transactions/:transaction_id/mark_invalid",
      TransactionDataController,
      :mark_invalid
    )

    post("/transaction", TransactionDataController, :save_transaction)

    get(
      "/transactions/probable_duplicate_buildings_list",
      TransactionDataController,
      :probable_duplicate_buildings_list
    )

    get(
      "/transactions/search_all_similar_buildings",
      TransactionDataController,
      :search_all_similar_buildings
    )

    get(
      "/transactions/search_db_buildings",
      TransactionDataController,
      :search_db_buildings
    )

    post(
      "/transactions/merge_incorrect_buildings",
      TransactionDataController,
      :merge_incorrect_buildings
    )

    get(
      "/transactions/fetch_random_processed_transaction",
      TransactionDataController,
      :fetch_random_processed_transaction
    )

    post(
      "/transactions/:transaction_id/mark_processed_data",
      TransactionDataController,
      :mark_processed_data
    )

    post(
      "/transactions/hide_temp_building",
      TransactionDataController,
      :hide_temp_building
    )

    # FeedTransaction Localities
    get("/feed_transaction_localities", FeedTransactionController, :admin_search_feed_localities)
    get("/feed_transaction_localities/:feed_locality_id", FeedTransactionController, :admin_fetch_feed_locality)
    patch("/feed_transaction_localities/:feed_locality_id", FeedTransactionController, :admin_update_feed_locality)

    post("/posts/:post_type/property/owner", PostController, :create_owner_post)
    post("/posts/:post_type/property/owner/all", PostController, :fetch_owner_posts)
    post("/posts/:post_type/property/broker/all", PostController, :fetch_property_posts)
    post("/posts/:post_type/client/broker/all", PostController, :fetch_client_posts)
    post("/posts/:post_type/property/owner/:post_uuid/archive", PostController, :archive_owner_post)
    post("/posts/:post_type/property/owner/:post_uuid/edit", PostController, :edit_owner_post)
    post("/posts/:post_type/property/owner/:post_uuid/restore", PostController, :restore_owner_post)
    post("/posts/:post_type/property/owner/:post_uuid/refresh", PostController, :refresh_owner_post)
    post("/posts/:post_type/property/owner/:post_uuid/verify", PostController, :verify_owner_post)
    post("/posts/:post_type/reported-property/owner/:post_id/refresh", PostController, :refresh_reported_owner_post)
    post("/matches/owner/:id", MatchController, :fetch_owner_matches)
    post("/matches/:match_type/all", MatchController, :fetch_matches)
    post("/owner/mark-broker/:id", OwnerController, :update_broker_flag)
    get("/owner/search-by-phone", OwnerController, :get_owner)
    post("/posts/property/owner/polygons", PostController, :fetch_owner_posts_polygon_distribution)

    get("/subscriptions", SubscriptionsController, :fetch_subscriptions)

    post(
      "/subscriptions/send_owner_listings_notifications",
      SubscriptionsController,
      :send_owner_listings_notifications
    )

    # Legal Entities APIs
    get("/legal_entity/all", LegalEntityController, :all_legal_entities)
    get("/legal_entity/:uuid/fetch", LegalEntityController, :show)
    post("/legal_entity", LegalEntityController, :create_legal_entity)
    post("/legal_entity/:uuid/update", LegalEntityController, :update_legal_entity)
    get("/legal_entity/search", LegalEntityController, :admin_search)

    # Legal Entity POC APIs
    get("/legal_entity_poc/all", LegalEntityPocController, :all_legal_entity_poc)
    get("/legal_entity_poc/:uuid/fetch", LegalEntityPocController, :show)
    post("/legal_entity_poc", LegalEntityPocController, :create_legal_entity_poc)
    post("/legal_entity_poc/:uuid/update", LegalEntityPocController, :update_legal_entity_poc)
    get("/legal_entity_poc/search", LegalEntityPocController, :admin_search)

    # Calling api for outbound
    post("/call/homeloan/connect", CallController, :connect_call)

    # Raw Posts APIs
    post("/raw_posts/:property_type/overview", RawPostController, :overview)
    post("/raw_posts/:property_type", RawPostController, :index)
    post("/raw_posts/:property_type/download_csv", RawPostController, :download_csv)
    get("/raw_posts/:property_type/:uuid", RawPostController, :fetch)
    post("/raw_posts/:property_type/:uuid/mark_as_junk", RawPostController, :mark_as_junk)
    post("/raw_posts/:property_type/:uuid/update_disposition", RawPostController, :update_disposition)

    # Invoice Panel APIs
    get("/invoices/meta", InvoiceController, :invoices_meta)
    get("/invoices/all", InvoiceController, :all_invoices)
    get("/invoices/:uuid/fetch", InvoiceController, :fetch_invoice_by_uuid)
    post("/invoices/:uuid/update", InvoiceController, :update_invoice_by_uuid)
    get("/invoices/:uuid/generate-invoice-pdf", InvoiceController, :admin_generate_invoice_pdf)
    get("/invoices/:invoice_uuid/generate-booking-invoice-pdf", InvoiceController, :admin_create_booking_invoice_pdf)
    post("/invoices/:uuid/mark-as-approved", InvoiceController, :mark_as_approved)
    post("/invoices/:uuid/mark-as-rejected", InvoiceController, :mark_as_rejected)
    post("/invoices/:uuid/request-changes", InvoiceController, :request_changes)
    post("/invoices/:uuid/update-number-and-date", InvoiceController, :update_invoice_number_and_date)
    post("/invoices/:uuid/mark-as-paid", InvoiceController, :mark_as_paid)
    post("/invoices/mark-to-be-paid", Admin.InvoiceController, :mark_invoice_to_be_paid)
    post("/invoices/mark-to-be-paid/otp", Admin.InvoiceController, :action_otp)
    get("/invoices/payment/logs/:invoice_id", Admin.InvoiceController, :get_payment_logs)
    post("/invoices/:uuid/change-status", InvoiceController, :change_status)
    get("/invoices/:uuid/admin_generate_signed_tnc_pdf/", InvoiceController, :admin_generate_signed_tnc_pdf)
    patch("/invoices/:uuid", InvoiceController, :update_invoice_by_uuid_for_dsa)
    get("/invoices/logs/:invoice_id", InvoiceController, :get_invoice_logs)
    post("/invoices/:invoice_id/add-remark", InvoiceController, :add_remark)
    patch("/invoices/:invoice_remark_id/edit-remark", InvoiceController, :edit_remark)
    patch("/invoices/:invoice_remark_id/delete-remark", InvoiceController, :delete_remark)

    # Priority Story Panel Apis
    scope "/priority_stories", Admin do
      get("/", PriorityStoryController, :list_all_priority_stories)
      post("/", PriorityStoryController, :prioritize_story)
      patch("/:id/delete", PriorityStoryController, :delete_priority_story)
      patch("/:id/change", PriorityStoryController, :change_priority_story)
    end

    # Bank APIs
    post("/banks", BankController, :add_bank)
    patch("/banks/:id", BankController, :update_bank)
    get("/banks/all", BankController, :get_all_banks)
  end

  scope "/prl", BnApisWeb do
    pipe_through(:prl_session_api)

    post("/invoices/post-invoice", InvoiceController, :post_piramal_invoice_to_panel)
  end

  scope "/admin", BnApisWeb, as: :admin do
    pipe_through(:admin_session_api)

    scope "/v1", V1, as: :v1 do
      post("/homeloan/leads-data", HomeloanController, :aggregate_leads)
      get("/homeloan/leads-data", HomeloanController, :aggregate_leads)
      get("/homeloan/leads-by-status", HomeloanController, :lead_list_by_filter)
      patch("/homeloan/leads/:id", HomeloanController, :update_lead_by_agent)
      post("/homeloan/coapplicants/:id", HomeloanController, :add_coapplicant)
      patch("/homeloan/coapplicants/:id", HomeloanController, :update_coapplicant)
      post("/homeloan/update-docs", HomeloanController, :update_doc)
      post("/homeloan/transfer-leads", HomeloanController, :transfer_leads)
      post("/homeloan/update-active-hl-agents", HomeloanController, :update_active_hl_agents)
      get("/homeloan/lead/:id", HomeloanController, :get_lead_details)
      post("/homeloan/add-loan-disbursement", HomeloanController, :add_homeloan_disbursement_from_panel)
      patch("/homeloan/edit-disbursement/:id", HomeloanController, :edit_homeloan_disbursement_from_panel)
      patch("/homeloan/delete-disbursement/:id", HomeloanController, :delete_homeloan_disbursement_from_panel)
      post("/homeloan/leads/employee_view", HomeloanController, :get_all_leads_for_employee_view)
      post("/homeloan/leads/dsa_view", HomeloanController, :get_all_leads_for_dsa_view)
      post("/homeloan/leads", HomeloanController, :get_lead_for_panel_view)
      post("/homeloan/upload-document", HomeloanController, :re_upload_documents)
      patch("/homeloan/lead/delete/:id", HomeloanController, :delete_lead_from_admin)
      patch("/homeloan/lead/change_commission_on", HomeloanController, :change_commission_on_from_panel)

      post(
        "/homeloan/update-lead-status",
        HomeloanController,
        :update_lead_status
      )

      post("/homeloan/add-note", HomeloanController, :add_note)

      get(
        "/homeloan/leads-by-phone",
        HomeloanController,
        :leads_by_phone_number
      )

      get("/homeloan/leads/doc-types", HomeloanController, :get_doc_types)
      post("/homeloan/leads/upload_document", HomeloanController, :admin_upload_document)
      post("/homeloan/leads/delete_document", HomeloanController, :admin_delete_document)
      get("/homeloan/leads/documents", HomeloanController, :admin_get_documents)

      # Loan file Admin APIs
      post("/homeloan/create-loan-file", HomeloanController, :create_loan_file_from_panel)
      patch("/homeloan/:loan_file_id/update-loan-file", HomeloanController, :update_loan_file_from_panel)

      # zone apis for panel
      get("/zones", ZoneController, :index)
      get("/zone/:uuid", ZoneController, :show)
      post("/zone", ZoneController, :create)
      patch("/zone", ZoneController, :update)

      # city apis for panel
      get("/cities", CityController, :get_cities_list)
      post("/cities", CityController, :update_city)

      post("/cabs/requests/assign/:id", CabsController, :assign_chauffeur)
      post("/cabs/requests/cancel/:id", CabsController, :cancel_request)
      post("/cabs/requests/complete/:id", CabsController, :complete_request)
      post("/cabs/requests/update/:id", CabsController, :update_vehicle_in_booking_request)
      get("/cabs/requests", CabsController, :get_all_booking_requests)
      get("/cabs/requests/logs/:id", CabsController, :get_logs_for_booking_request)
      post("/cabs/requests/messages", CabsController, :send_messages_for_booked_cabs)
      post("/cabs/requests/whatsapp-sent/:id", CabsController, :update_whatsapp_sent)
      post("/cabs/requests/send-message", CabsController, :send_message)
      post("/cabs/requests/reroute", CabsController, :create_reroute_booking)

      get("/cabs/requests/slots", CabsController, :list_booking_slots)
      get("/cabs/requests/slots/:id", CabsController, :get_booking_slot)
      post("/cabs/requests/slots", CabsController, :create_booking_slot)
      post("/cabs/requests/slots/:id", CabsController, :update_booking_slot)

      get("/cabs/operators", CabsController, :list_operators)
      post("/cabs/operators", CabsController, :create_operator)
      post("/cabs/operators/:id", CabsController, :update_operator)

      get("/cabs/vehicles", CabsController, :list_vehicles)
      get("/cabs/vehicles/:id", CabsController, :get_cab_vehicle_data)
      post("/cabs/vehicles", CabsController, :create_vehicle)
      post("/cabs/vehicles/:id", CabsController, :update_vehicle)

      get("/cabs/drivers", CabsController, :list_drivers)
      post("/cabs/drivers", CabsController, :create_driver)
      post("/cabs/drivers/:id", CabsController, :update_driver)

      get("/orders/match_plus", OrdersController, :fetch_match_plus)
      get("/match_plus/:broker_id", OrdersController, :fetch_broker_match_plus)
      post("/rewards-requests/index", RewardsController, :get_rewards_leads)
      post("/rewards-requests/aggregate", RewardsController, :get_rewards_leads_aggregate)
      post("/rewards-requests/approve/:lead_id", RewardsController, :approve_rewards_request_by_manager)
      post("/rewards-requests/reject/:lead_id", RewardsController, :reject_rewards_request_by_manager)
      post("/rewards-requests/close/:lead_id", RewardsController, :close_rewards_request_by_manager)
      get("/rewards/disabled_rewards_reasons/", RewardsController, :get_disabled_rewards_reasons)

      # Reminder APIS
      get("/homeloan/:entity_id/reminders", ReminderController, :get_hl_reminders_for_entity_id)
      post("/homeloan/reminders", ReminderController, :create_hl_reminder)
      patch("/reminders/:id", ReminderController, :update_hl_reminder)
      patch("/reminders/:id/complete", ReminderController, :complete_reminder)
      patch("/reminders/:id/cancel", ReminderController, :cancel_reminder)

      get("/commercial/post/:post_uuid/get", CommercialController, :admin_get_post)
      post("/commercial/post/all", CommercialController, :admin_list_post)

      # Raw posts
      scope "/raw_posts", RawPosts do
        post("/:property_type/create", RawPostController, :create)
        post("/:property_type/:uuid/update", RawPostController, :update)
      end

      # Slack API
      post("/notifications/slack", CommonController, :notify_on_slack)

      # Random Token API
      get("/generate_token", CommonController, :generate_random_token)
    end

    scope "/v2", V2 do
      post(
        "/homeloan/update-lead-status",
        HomeloanController,
        :update_lead_status
      )
    end

    scope "/v2", V2 do
      get("/homeloan/leads-data", HomeloanController, :aggregate_leads)
      get("/homeloan/leads-by-status", HomeloanController, :lead_list_by_filter)

      get(
        "/homeloan/leads-by-phone",
        HomeloanController,
        :leads_by_phone_number
      )
    end

    # Owner Panel APIs
    get("/ownerpanel/membership/:id/orders", OwnerPanelController, :get_membership_orders)
    get("/ownerpanel/razorpay/orders", OwnerPanelController, :get_razorpay_orders)
    get("/ownerpanel/owner_details", OwnerPanelController, :get_membership_details)
    get("/ownerpanel/active_owners_count", OwnerPanelController, :get_active_memberships_count)
    get("/ownerpanel/new_memberships_count", OwnerPanelController, :get_pg_new_and_autopay_memberships_count)
    post("/ownerpanel/offline_payment", OwnerPanelController, :create_offline_payment)
    post("/ownerpanel/payments_summary", OwnerPanelController, :payments_summary)

    # commercials Panel APIs
    get("/commercial/meta_data", CommercialController, :meta_data)
    post("/commercial/post/:post_uuid/update", CommercialController, :update_post)
    get("/commercial/post/:post_uuid/get", CommercialController, :admin_get_post)
    post("/commercial/post/all", CommercialController, :admin_list_post)
    post("/commercial/post/create", CommercialController, :create_post)
    post("/commercial/post/upload_document", CommercialController, :upload_document)
    patch("/commercial/post/remove_document", CommercialController, :remove_document)
    get("/commercial/post/document/:post_uuid", CommercialController, :get_document)
    post("/commercial/poc/create_or_update", CommercialController, :create_or_update_poc)
    get("/commercial/poc/search", CommercialController, :search_poc)
    post("/commercial/visits/all", CommercialController, :list_site_visits)
    get("/commercial/visit/get/:visit_id", CommercialController, :get_site_visit)
    patch("/commercial/visit/cancel/:visit_id", CommercialController, :cancel_site_visit)
    patch("/commercial/visit/complete/:visit_id", CommercialController, :complete_site_visit)
    get("/commercial/post/report/:post_uuid", CommercialController, :get_report)
    post("/commercial/aggregate", CommercialController, :aggregate)
    post("/commercial/chat/channel/create", CommercialController, :create_channel_for_admin)
    get("/commercial/chat/channel/fetch/:channel_url", CommercialController, :fetch_channel_info_for_admin)
    post("/commercial/post/status/update_all", CommercialController, :update_status_for_multiple_posts)

    # booking reward form APIs
    scope "/booking_reward", Admin do
      get("/fetch/:status", BookingRewardsController, :fetch_booking_form)
      patch("/:uuid/status/:status", BookingRewardsController, :update_booking_form)
      patch("/:uuid", BookingRewardsController, :update_booking_form)
      get("/:uuid", BookingRewardsController, :fetch_booking_form_for_uuid)
      get("/:uuid/generate-pdf", BookingRewardsController, :generate_booking_reward_pdf)
    end

    # Campaign Panel APIs
    scope "/campaign", Admin do
      post("/affected-brokers", CampaignManagerController, :affected_brokers_count)
      get("/stats/all", CampaignManagerController, :fetch_all_campaign_with_details)
      get("/fetch/:id", CampaignManagerController, :fetch_campaign)
      post("/update-campaign/:id", CampaignManagerController, :update_campaign)
      post("/create-campaign", CampaignManagerController, :create_campaign)
    end

    # Billing Company Panel APIs
    scope "/billing_companies", Admin do
      get("/all", BillingCompanyController, :all_billing_companies)
      get("/:uuid/fetch", BillingCompanyController, :fetch_billing_company)
      post("/:uuid/mark-as-approved", BillingCompanyController, :mark_as_approved)
      post("/:uuid/mark-as-rejected", BillingCompanyController, :mark_as_rejected)
      post("/:uuid/request-changes", BillingCompanyController, :request_changes)
      post("/:uuid/move-to-pending", BillingCompanyController, :move_to_pending)
    end

    # Mandate Company Panel APIs
    scope "/mandate_company", Admin do
      get("/all", MandateCompanyController, :all_mandate_companies)
      get("/:id/fetch", MandateCompanyController, :fetch_mandate_company)
      get("/search", MandateCompanyController, :admin_search_mandate_company)
      patch("/:id/update", MandateCompanyController, :update_mandate_company)
      post("/create", MandateCompanyController, :create_mandate_company)
    end

    ## Assited Model apis
    post("/posts/:post_type/owner/assisted_property", AssistedPropertyController, :fetch_assisted_property)
    post("/posts/owner/update_assisted_property/:assisted_property_post_agreement_uuid", AssistedPropertyController, :update_assisted_property)
    post("/posts/owner/assisted_property/upload_document/:assisted_property_post_agreement_uuid", AssistedPropertyController, :upload_document)
    patch("/posts/owner/assisted_property/remove_document/:assisted_property_post_agreement_uuid", AssistedPropertyController, :remove_document)
    get("/posts/owner/assisted_property/document/:assisted_property_post_agreement_uuid", AssistedPropertyController, :get_document)
    post("/posts/:post_type/owner/assisted_property/:post_uuid/assign_manager", AssistedPropertyController, :assign_manager)
    get("/posts/:post_type/owner/assisted_property/overview", AssistedPropertyController, :overview)
    post("/posts/owner/assisted_property/fetch_agreement/:assisted_property_post_agreement_uuid", AssistedPropertyController, :fetch_agreement)
    get("/posts/owner/assisted_property/validate_agreement/:assisted_property_post_agreement_uuid", AssistedPropertyController, :validate_owner_agreement)
  end

  scope "/api/internal", BnApisWeb do
    pipe_through(:internal_session_api)

    get("/entities/search", FeedTransactionController, :entities_search)
    get("/feed_transactions", FeedTransactionController, :index)
    post("/feed_transactions", FeedTransactionController, :create)
    post("/feed_transactions/create_or_update", FeedTransactionController, :create_or_update)

    resources("/transactions_data", TransactionDataController, except: [:new, :edit])

    get("/transactions_districts", TransactionDataController, :list_districts)

    get(
      "/transactions_data/:sro_id/fetch_from_sro",
      TransactionDataController,
      :fetch_data_from_sro
    )

    get(
      "/transactions_data/:year/:sro_id/:document_id/check_if_exists",
      TransactionDataController,
      :check_if_exists
    )
  end

  scope "/developer", BnApisWeb do
    pipe_through(:api)

    post("/send_otp", DeveloperCredentialController, :send_otp)
    post("/resend_otp", DeveloperCredentialController, :resend_otp)
    post("/verify_otp", DeveloperCredentialController, :verify_otp)
  end

  scope "/developer", BnApisWeb do
    pipe_through(:developer_session_api)

    post("/signout", DeveloperCredentialController, :signout)
    post("/validate", DeveloperCredentialController, :validate)
    # @deprecated "rewards_leads is being used now."
    post("/site_visits", DeveloperCredentialController, :create_site_visits)
  end

  scope "/developer-poc", BnApisWeb do
    get("/base_remote_config", FirebaseController, :builder_base_remote_config)
  end

  scope "/developer-poc", BnApisWeb do
    pipe_through(:api)

    scope "/v1", V1 do
      post("/send_otp", DeveloperPocCredentialController, :send_otp)
      post("/resend_otp", DeveloperPocCredentialController, :resend_otp)
      post("/verify_otp", DeveloperPocCredentialController, :verify_otp)
    end
  end

  scope "/developer-poc", BnApisWeb do
    pipe_through(:developer_poc_session_api)

    scope "/v1", V1 do
      get("/metadata", CommonController, :get_metadata)
      get("/broker-history", RewardsController, :broker_history)
      post("/signout", DeveloperPocCredentialController, :signout)
      post("/validate", DeveloperPocCredentialController, :validate)
      patch("/update_fcm_id", DeveloperPocCredentialController, :update_fcm_id)

      get(
        "/rewards-requests/pending",
        RewardsController,
        :get_pending_rewards_request
      )

      get(
        "/rewards-requests/rejected",
        RewardsController,
        :get_rejected_rewards_request
      )

      get(
        "/rewards-requests/approved",
        RewardsController,
        :get_approved_rewards_request
      )

      get("/rewards-requests/search", RewardsController, :search_leads)

      post(
        "/rewards-requests/approve",
        RewardsController,
        :approve_rewards_request
      )

      post(
        "/rewards-requests/reject",
        RewardsController,
        :reject_rewards_request
      )
    end
  end

  scope "/on_ground", BnApisWeb do
    get("/base_remote_config", FirebaseController, :onground_base_remote_config)
  end

  scope "/on_ground", BnApisWeb do
    pipe_through(:on_ground_session_api)

    get("/dashboard", AssignedBrokerController, :dashboard)
    get("/broker", AssignedBrokerController, :fetch_broker)
    get("/search", AssignedBrokerController, :search_broker)
    get("/organizations/search", AssignedBrokerController, :search_organization)
    get("/remote_config", FirebaseController, :onground_remote_config)

    get(
      "/:org_uuid/organization",
      AssignedBrokerController,
      :fetch_assigned_org_details
    )

    post("/snooze", AssignedBrokerController, :snooze)
    post("/mark_lost", AssignedBrokerController, :mark_as_lost)
    post("/note", AssignedBrokerController, :add_note)
    post("/call_log", AssignedBrokerController, :create_call_log)
    post("/employee_credentials/fcm_id", EmployeeCredentialController, :update_fcm_id)
    get("/chat/fetch_channel", AssignedBrokerController, :fetch_or_create_sendbird_channel_for_broker)

    scope "/v1", V1 do
      post("/rewards-requests/index", RewardsController, :get_rewards_leads)
      post("/rewards-requests/aggregate", RewardsController, :get_rewards_leads_aggregate)
      post("/rewards-requests/approve/:lead_id", RewardsController, :approve_rewards_request_by_manager)
      post("/rewards-requests/reject/:lead_id", RewardsController, :reject_rewards_request_by_manager)
      post("/rewards-requests/close/:lead_id", RewardsController, :close_rewards_request_by_manager)
      post("/entities/search", CommonController, :search_entities_for_employee)
      get("/brokers", AssignedBrokerController, :list_assigned_brokers)

      # Meetings API for onground app
      post("/meetings", MeetingController, :create_meeting)
      get("/meetings", MeetingController, :get_meetings)
      patch("/meetings/:id", MeetingController, :update_meeting)

      post("/meetings/verify-qr-code", MeetingController, :verify_qr_code)

      get("/broker/reminders", ReminderController, :get_broker_reminders_for_employee)
      post("/broker/reminders", ReminderController, :create_broker_reminder)
      patch("/reminders/:id", ReminderController, :update_broker_reminder)
      patch("/reminders/:id/complete", ReminderController, :complete_reminder)
      patch("/reminders/:id/cancel", ReminderController, :cancel_reminder)
    end
  end

  scope "/legal_entity_poc", BnApisWeb do
    scope "/v1", V1 do
      post("/send_otp", LegalEntityPocController, :send_otp)
      post("/verify_otp", LegalEntityPocController, :verify_otp)
    end

    scope "/v1", V1 do
      pipe_through(:legal_entity_poc_api)

      post("/validate", LegalEntityPocController, :validate)

      post("/:invoice_uuid/:action/otp", LegalEntityPocController, :action_otp)

      post("/:invoice_uuid/approve", LegalEntityPocController, :approve)
      post("/:invoice_uuid/reject", LegalEntityPocController, :reject)
      post("/:invoice_uuid/change", LegalEntityPocController, :request_change)
      get("/all-invoices", LegalEntityPocController, :all_invoices)
      patch("/:br_uuid/approve_booking_reward", LegalEntityPocController, :approve_booking_reward)
      patch("/:br_uuid/reject_booking_reward", LegalEntityPocController, :reject_booking_reward)
      post("/:br_uuid/change_booking_reward", LegalEntityPocController, :request_change_booking_reward)
      get("/all-booking-rewards", LegalEntityPocController, :all_booking_rewards)
    end
  end
end
