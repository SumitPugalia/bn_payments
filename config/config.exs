# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :bn_apis,
  ecto_repos: [BnApis.Repo]

config :bn_apis, BnApis.Repo,
  queue_target: 5000,
  extensions: [{Geo.PostGIS.Extension, library: Geo}],
  loggers: [Appsignal.Ecto, Ecto.LogEntry]

adapter_config = if Mix.env() == :test, do: [], else: [adapter: Phoenix.PubSub.PG2]

# Configures the endpoint
config :bn_apis, BnApisWeb.Endpoint,
  url: [host: "localhost"],
  render_errors: [view: BnApisWeb.ErrorView, accepts: ~w(html json), layout: false],
  pubsub_server: BnApis.PubSub,
  live_view: [signing_salt: "dVNTb8DiLITnihqBvQV5IqaZq4UnbsxbntnGFh7FDjYMlP9B9oaET7qOUT+eFek"]

# Configures the mailer
#
# By default it uses the "Local" adapter which stores the emails
# locally. You can see the emails in your browser, at "/dev/mailbox".
#
# For production it's recommended to configure a different adapter
# at the `config/runtime.exs`.
# config :sample_app, SampleApp.Mailer, adapter: Swoosh.Adapters.Local

# Swoosh API client is needed for adapters other than SMTP.
# config :swoosh, :api_client, false

# Configure esbuild (the version is required)
config :esbuild,
  version: "0.14.29",
  default: [
    args: ~w(js/app.js --bundle --target=es2017 --outdir=../priv/static/assets --external:/fonts/* --external:/images/*),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
  ]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

config :logger, :console, format: "[$level] $message\n", metadata: [:request_id]

config :geo_postgis,
  json_library: Jason

config :exq_ui,
  web_port: 4042,
  web_namespace: "bn_exq_ui",
  server: true

config :bn_apis, BnApis.Scheduler,
  jobs: [
    # 5:30AM and 6:30PM
    {"0 1 * * *", {BnApis.MonitorApp, :uninstall, []}},
    # 10AM
    {"30 4 * * *", {BnApis.PostsNotification, :expiring_posts, []}},
    # 9AM and 1PM
    {"30 3 * * *", {BnApis.PostsNotification, :expired_posts, []}},
    # 7PM
    # {"30 13 * * *", {BnApis.PostsNotification, :new_posts_update, []}},
    # 9PM
    # {"30 15 * * *", {BnApis.PostsNotification, :create_posts, []}},
    # 11AM, 2PM, 6PM and 9PM
    # {"30 5,8,12,15 * * *", {BnApis.PostsNotification, :no_action_on_matches, []}},
    # 2AM
    {"30 2 * * *", {BnApis.MonitorApp, :remove_tmp_files, []}},
    # 10 AM
    {"30 4 * * *", {BnApis.Homeloan.UpdateHomeloanLeadStatusWorker, :perform, []}},
    # 06:35 PM => 12:05 AM IST
    {"30 15 * * *", {BnApis.Cabs.MarkBookingRequestsAsCompletedWorker, :perform, []}},
    # 1 AM => 6:30 AM IST
    {"0 1 * * *", {BnApis.Rewards.UpdatePendingPayoutsWorker, :perform, []}},
    # 1 AM
    {"0 1 * * *", {BnApis.Subscriptions.UpdateMatchPlusStatusWorker, :perform, []}},
    # 1 AM
    {"0 1 * * *", {BnApis.Orders.UpdateMatchPlusCronWorker, :perform, []}},
    # 1 AM
    {"0 1 * * *", {BnApis.Memberships.UpdateMatchPlusMembershipCronWorker, :perform, []}},
    # 1 AM
    {"0 1 * * *", {BnApis.Subscriptions.UpdateSubscriptionStatusCronWorker, :perform, []}},
    # Every 30 minutes
    {"*/5 * * * *", {BnApis.Orders.UpdateOrderStatusCronWorker, :perform, []}},
    # Every 30 minutes
    {"*/30 * * * *", {BnApis.Memberships.UpdatePendingMembershipStatusCronWorker, :perform, []}},
    # 1 AM
    {"0 1 * * *", {BnApis.Memberships.CancelNonRenewedMembershipsWorker, :perform, []}},
    # 3:30 AM => 9 AM IST
    {"30 3 * * *", {BnApis.Memberships.NotifyExpiringMembershipsCronWorker, :perform, []}},
    # 9:00 AM IST
    {"30 3 * * *", {BnApis.Posts.NotifyExpiringPostsCronWorker, :perform, []}},
    # 9:30 AM IST
    {"0 4 * * *", {BnApis.Posts.SendReminderForExpiringPostsCronWorker, :perform, []}},
    # 12:30 P.M IST
    {"0 7 * * *", {BnApis.Posts.PushLeadForOwnerNotRegisteredOnWhatsapp, :perform, []}},
    {"0 4,10,14 * * *", {BnApis.NotificationAnalytics, :perform, []}},
    # 9:30 AM
    {"0 2 * * *", {BnApis.SendTransactionDataNotification, :perform, []}},
    # 5 AM UTC == 10:30 AM IST
    {"0 3 * * *", {BnApis.Subscriptions.NewOwnerListingsNotificationCronWorker, :perform, []}},
    {"30 3 * * *", {BnApis.Rewards.StoryAmountReconcileNotificationWorker, :perform, []}},
    {"30 1 * * *", {BnApis.Rewards.RetryReversedPayoutsWorker, :perform, []}},
    {"30 4 * * *", {BnApis.Rewards.ProcessStuckRewards, :perform, []}},
    {"30 0 * * *", {BnApis.Rewards.RetryReversedEmployeePayoutsWorker, :perform, []}},
    {"30 4 * * *", {BnApis.Subscriptions.BrokerAssignedManagers, :perform, []}},
    {"30 3 * * 4", {BnApis.Projects.NewProjectsWeeklyNotificationWorker, :perform, []}},
    # {"30 2 * * *", {BnApis.Rewards.AutomateLeadApproveWorker, :perform, []}}
    # every day at 9 :00 PM IST == 3:30 UTC
    {"30 15 * * *", {BnApis.Cabs.DiscardReroutingRequest, :perform, []}},
    # every day at 01:00 AM IST == 19:30 UTC
    {"30 19 * * *", {BnApis.Posts.DeleteShareableImagesS3, :perform, []}},
    {"1 * * * *", {BnApis.Rewards.UpdatePayoutStatusForMissedWebhooks, :perform, []}},
    # Every 15 mins
    {"*/15 * * * *", {BnApis.RegisterHlAgentOnSendbird, :perform_cron, []}},
    # Every 30 mins
    {"*/30 * * * *", {BnApis.CreateHLSendbirdChannel, :perform_cron, []}},
    # Every 4 hours
    # {"0 */4 * * *", {BnApis.Commercial.AddCommercialUserInChannel, :perform, []}},
    # Every hour
    {"0 * * * *", {BnApis.RawPosts.SendPendingRawPostsToSlashWorker, :perform, []}},
    # every day at 11:00 PM IST == 3:30 UTC
    {"30 17 * * *", {BnApis.BookingRewards.MarkExpiredBookingRewardWorker, :perform, []}},
    {"30 3 * * 4", {BnApis.Projects.RewardsActivatedWeeklyNotificationWorker, :perform, []}},
    {"0 * * * *", {BnApis.RawPosts.PushDraftDispositionRawPostsToSlashWorker, :perform, []}},
    # Every hour
    # {"0 * * * *", {BnApis.Rewards.AutomateLeadApproveWorker, :perform, []}},
    # 5:30 AM UTC == 11:00 AM IST
    # {"30 5 * * *", {BnApis.Commercial.CommercialAvailabilityNotification, :perform, []}},
    # 6:00 AM UTC == 11:30 AM IST
    # {"0 6 * * *", {BnApis.Commercial.CommercialAvailabilityResponseNotification, :perform, []}},
    # 5:00 AM UTC == 10:30 AM IST
    # {"0 5 * * *", {BnApis.Commercial.CommercialAvailabilityNoResponseReminder, :perform, []}},
    # 5:30 AM UTC == 11:00 AM IST
    # {"30 5 * * *", {BnApis.Commercial.PostsNotifications, :perform, []}},
    # Every day at 8:00 PM IST == 2:30 UTC
    {"30 14 * * *", {BnApis.Organizations.OrgJoiningRequests, :expire_organization_joining_requests, []}},
    # # 4:30 AM UTC == 10:00 AM IST
    # {"30 4 * * *", {BnApis.Rewards.AutoApproveLeadReminder, :perform, []}},
    # # 8:30 AM UTC == 2:00 pM IST
    # {"30 8 * * *", {BnApis.Rewards.AutoApproveLeadReminder, :perform, []}},
    # # 10:30 AM UTC == 4:00 PM IST
    # {"30 10 * * *", {BnApis.Rewards.AutoApproveLeadReminder, :perform, []}},
    # 13:30 AM UTC == 7:00 PM IST Saturday
    {"30 13 * * 6", {BnApis.Rewards.SvLeadSummaryNotificationToDevPoc, :perform, []}},
    # 13:30 AM UTC == 7:00 PM IST Sunday
    {"30 13 * * 0", {BnApis.Rewards.SvLeadSummaryNotificationToDevPoc, :perform, []}},
    # Every 30 mins
    {"*/30 * * * *", {BnApis.Subscriptions.UpdateUserPackageStatusWorker, :perform, []}},
    # In Every 5 min
    {"*/5 * * * *", {BnApis.Workers.Invoice.InvoiceRazorpayFallbackWorker, :perform, []}}
  ]

config :bn_apis,
  google_maps_helper_module: BnApis.Helpers.GoogleMapsHelper

config :bn_apis, BnApis.IpLoc.API,
  base_url: "https://pro.ip-api.com/json",
  fields: "180242",
  key: "jOdCE1gkBmsSv4q"

config :bn_apis, BnApis.Helpers.GoogleMapsHelper, autocomplete_url: "https://maps.googleapis.com/maps/api/place/autocomplete/json"

## Run X server for simultaneous PDF generation .. Bug in library
config :pdf_generator,
  command_prefix: ["xvfb-run", "-a"],
  use_chrome: true,
  prefer_system_executable: true,
  raise_on_missing_wkhtmltopdf_binary: false

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"

import_config "logger.exs"
