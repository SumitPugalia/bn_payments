import Config

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :bn_apis, BnApisWeb.Endpoint,
  http: [port: 4002],
  server: false

# Print only warnings and errors during test
config :logger, level: :warn

config :bn_apis, BnApis.Repo,
  adapter: Ecto.Adapters.Postgres,
  username: "postgres",
  password: "postgres",
  database: "bn_apis_test",
  hostname: "localhost",
  port: 5432,
  types: BnApis.PostgresTypes,
  stacktrace: true,
  pool_size: 10,
  pool: Ecto.Adapters.SQL.Sandbox

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

config :bn_apis,
  razorpay_url: "https://api.razorpay.com/",
  razorpay_account_number: "some-account-number",
  imgix_domain: "https://bn-temp.imgix.net",
  google_maps_helper_module: BnApis.Helpers.GoogleMapsHelperMock,
  bulksms_url: "https://bn_dummy.sms.brokernetwork"

config :bn_payments,
  http_client_opts: [],
  merchant_id: "fake",
  client_id: "fake",
  secret_key: "fake",
  bill_desk_endpoint: "",
  client_module: BnPayments.Stub

config :bn_payments,
   http_client_opts: [],
   merchant_id: "fake",
   client_id: "fake",
   secret_key: "fake",
   bill_desk_endpoint: "",
   client_module: BnPayments.Stub


config :bn_apis, BnApis.Helpers.ApplicationHelper, slack_message: SlackNotificationMock
config :bn_apis, BnApis.Helpers.S3Helper, s3_helper: S3Mock
config :bn_apis, BnApis.Helpers.Redis, redis_module: RedisMock
config :bn_apis, BnApis.HTTP, module_name: HTTPMock
config :bn_apis, BnApis.Helpers.HtmlHelper, html_helper: HtmlMock

config :pdf_generator,
  command_prefix: [],
  raise_on_missing_wkhtmltopdf_binary: false

config :bn_apis, BnApis.PaymentGateway.API, payment_gateway_module: PaymentGatewayMock

config :bn_apis, BnApis.Helpers.SmsService, sms_service_module: SmsServiceMock
config :bn_apis, BnApis.Helpers.OtpSmsHelper, module_name: SmsOtpServiceMock

config :exq,
  queue_adapter: Exq.Adapters.Queue.Mock,
  start_on_application: false

config :redix,
  host: "127.0.0.1",
  port: 6379
