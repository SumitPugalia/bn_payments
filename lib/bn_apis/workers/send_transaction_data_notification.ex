defmodule BnApis.SendTransactionDataNotification do
  import Ecto.Query
  alias BnApis.Repo
  alias BnApis.FeedTransactions.FeedTransaction
  alias BnApis.FeedTransactions.FeedTransactionLocality
  alias BnApis.Accounts.Credential
  alias BnApis.Helpers.ApplicationHelper

  def perform() do
    find_and_send_notification()
  end

  def get_polygon_wise_count() do
    polygon_wise_count =
      FeedTransaction
      |> where([ft], fragment("?::date >= current_date - INTERVAL '1 day'", ft.inserted_at))
      |> group_by([ft], ft.feed_locality_id)
      |> select([ft], {ft.feed_locality_id, count(ft.id)})
      |> Repo.all()

    feed_locality_map =
      polygon_wise_count
      |> Enum.reduce(%{}, fn data, acc ->
        locality_id = elem(data, 0)

        if is_nil(acc[locality_id]) do
          Map.put(acc, locality_id, Repo.get_by(FeedTransactionLocality, feed_locality_id: locality_id))
        else
          acc
        end
      end)

    all_polygons =
      feed_locality_map
      |> Enum.map(fn {_, feed_transaction_locality} -> feed_transaction_locality.polygon_uuids end)
      |> Enum.filter(fn data -> not is_nil(data) end)
      |> List.flatten()
      |> Enum.uniq()

    cred_map =
      all_polygons
      |> Enum.reduce(%{}, fn polygon_uuid, acc ->
        if is_nil(acc[polygon_uuid]) do
          Map.put(
            acc,
            polygon_uuid,
            Credential.get_credentials_in_polygons([polygon_uuid], false)
            |> Enum.filter(fn cred -> not is_nil(cred.fcm_id) end)
          )
        else
          acc
        end
      end)

    polygon_wise_count_map =
      polygon_wise_count
      |> Enum.reduce(%{}, fn data, acc ->
        locality_id = elem(data, 0)
        count = elem(data, 1)
        feed_transaction_locality = feed_locality_map[locality_id]

        if not is_nil(feed_transaction_locality) do
          if not is_nil(feed_transaction_locality.polygon_uuids) do
            if not is_nil(feed_transaction_locality.polygon_uuids) do
              polygon_map =
                feed_transaction_locality.polygon_uuids
                |> Enum.reduce(%{}, fn polygon_uuid, polygon_acc ->
                  creds_in_polygon = cred_map[polygon_uuid]

                  if is_nil(acc[polygon_uuid]) do
                    Map.put(polygon_acc, polygon_uuid, %{
                      count: count,
                      locality_id: locality_id,
                      creds_in_polygon: creds_in_polygon || []
                    })
                  else
                    acc_polygon_uuid = acc[polygon_uuid]

                    Map.put(polygon_acc, polygon_uuid, %{
                      count: acc_polygon_uuid.count + count,
                      locality_id: locality_id,
                      creds_in_polygon: acc_polygon_uuid.creds_in_polygon ++ creds_in_polygon
                    })
                  end
                end)

              acc |> Map.merge(polygon_map)
            else
              acc
            end
          else
            acc
          end
        else
          acc
        end
      end)

    polygon_wise_count_map
  end

  def find_and_send_notification() do
    polygon_wise_count = get_polygon_wise_count()

    channel = ApplicationHelper.get_slack_channel()

    ApplicationHelper.notify_on_slack(
      "Starting to send transactions notifications",
      channel
    )

    polygon_wise_count
    |> Enum.each(fn {_polygon_uuid, polygon_data} ->
      polygon_data.creds_in_polygon
      |> Enum.each(fn cred ->
        fcm_data = %{
          "title" => "#{polygon_data.count} new transactions in #{cred.polygon_name || "in your locality"}.",
          "message" => "Click here to explore transactions data now.",
          "locality_id" => "#{polygon_data.locality_id}",
          "project_id" => ""
        }

        notif_type = "TRANSACTION_NOTIFICATION"

        Exq.enqueue(Exq, "send_transactions_notif", BnApis.Notifications.PushNotificationWorker, [
          cred.fcm_id,
          %{data: fcm_data, type: notif_type},
          cred.id,
          cred.notification_platform
        ])

        Process.sleep(200)
      end)
    end)

    ApplicationHelper.notify_on_slack(
      "Completed to send transactions notifications",
      channel
    )
  end
end
