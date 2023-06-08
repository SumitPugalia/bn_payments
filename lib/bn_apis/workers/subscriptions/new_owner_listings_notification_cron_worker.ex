defmodule BnApis.Subscriptions.NewOwnerListingsNotificationCronWorker do
  import Ecto.Query, warn: false
  alias BnApis.Repo
  alias BnApis.Helpers.ApplicationHelper
  alias BnApis.Accounts.Credential
  alias BnApis.Organizations.Broker
  alias BnApis.Buildings.Building
  alias BnApis.Places.{City, Polygon}
  alias BnApis.Posts.{ResalePropertyPost, RentalPropertyPost}

  def perform() do
    channel = ApplicationHelper.get_slack_channel()

    ApplicationHelper.notify_on_slack(
      "Starting to send new owner listings notifications",
      channel
    )

    City
    |> Repo.all()
    |> Enum.each(fn city ->
      if city.feature_flags["owners"] == true do
        send_notifications(city)
      end
    end)

    ApplicationHelper.notify_on_slack(
      "Finished sending new owner listings notifications",
      channel
    )
  end

  def send_notifications(city) do
    city_id = city.id
    today = Timex.now() |> Timex.Timezone.convert("Asia/Kolkata")
    day_before_yesterday = Timex.shift(today, days: -2)
    beginning_of_day_before_yesterday = Timex.beginning_of_day(day_before_yesterday)

    no_of_new_rental_listings =
      RentalPropertyPost
      |> join(:inner, [p], b in Building, on: p.building_id == b.id)
      |> join(:inner, [p, b], poly in Polygon, on: b.polygon_id == poly.id)
      |> where([p, b, poly], poly.city_id == ^city_id)
      |> where([p], p.uploader_type == "owner")
      |> where([p], p.test_post == false)
      |> where([p], p.inserted_at >= ^beginning_of_day_before_yesterday)
      |> where([p], fragment("? >= timezone('utc', NOW())", p.expires_in))
      |> BnApis.Repo.aggregate(:count, :id)

    no_of_new_resale_listings =
      ResalePropertyPost
      |> join(:inner, [p], b in Building, on: p.building_id == b.id)
      |> join(:inner, [p, b], poly in Polygon, on: b.polygon_id == poly.id)
      |> where([p, b, poly], poly.city_id == ^city_id)
      |> where([p], p.uploader_type == "owner")
      |> where([p], p.test_post == false)
      |> where([p], p.inserted_at >= ^beginning_of_day_before_yesterday)
      |> where([p], fragment("? >= timezone('utc', NOW())", p.expires_in))
      |> BnApis.Repo.aggregate(:count, :id)

    no_of_new_listings = no_of_new_rental_listings + no_of_new_resale_listings

    if no_of_new_listings > 0 do
      Credential
      |> join(:inner, [c], b in Broker, on: b.id == c.broker_id)
      |> where([c, b], c.active == true)
      |> where([c, b], not is_nil(c.fcm_id) and b.operating_city == ^city_id)
      |> Credential.filter_by_broker_role_type(false)
      |> Repo.all()
      |> Enum.each(fn credential ->
        title = "#{no_of_new_listings} new owner properties added today"
        message = "Explore Owner Listings Now!"
        type = "NEW_OWNER_LISTINGS"
        data = %{"title" => title, "message" => message}

        Exq.enqueue(Exq, "send_owner_notifs", BnApis.Notifications.PushNotificationWorker, [
          credential.fcm_id,
          %{data: data, type: type},
          credential.id,
          credential.notification_platform
        ])

        Process.sleep(100)
      end)
    end
  end
end
