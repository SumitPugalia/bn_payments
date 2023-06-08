defmodule Mix.Tasks.SendWhatsappMessageForAllExpiredPosts do
  use Mix.Task

  alias BnApis.Repo

  alias BnApis.Posts
  alias BnApis.Posts.RentalPropertyPost
  alias BnApis.Posts.ResalePropertyPost
  alias BnApis.Whatsapp.WhatsappRequest

  import Ecto.Query

  def run(_) do
    Mix.Task.run("app.start", [])
    notify_expired_posts()
  end

  def notify_expired_posts() do
    # It's about sending reminder messages to all the owners to whom messages have been delivered but they haven't replies yet.
    # start_time = Timex.now()
    # |> Timex.Timezone.convert("Asia/Kolkata")
    # |> Timex.beginning_of_day() |> Timex.shift(days: -90) |> DateTime.to_unix()

    end_time = Timex.now() |> DateTime.to_unix()

    rent_map = Posts.post_map("rent")
    resale_map = Posts.post_map("resale")

    list_rent_post_ids_whatsapp_msg_deliver = WhatsappRequest.list_of_entity_ids_for_delivered_messages(rent_map.table)

    list_resale_post_ids_whatsapp_msg_deliver = WhatsappRequest.list_of_entity_ids_for_delivered_messages(resale_map.table)

    RentalPropertyPost
    |> where([rp], rp.archived == false and not is_nil(rp.assigned_owner_id))
    |> where([rp], ^end_time > fragment("ROUND(extract(epoch from ?))", rp.expires_in))
    |> where([rp], rp.id in ^list_rent_post_ids_whatsapp_msg_deliver)
    |> Repo.all()
    |> Repo.preload([:building, :configuration_type, :furnishing_type, :assigned_owner])
    |> Enum.with_index()
    |> Enum.map(fn {post, index} ->
      notify_owner(post, index, "rent")
      Process.sleep(500)
    end)

    ResalePropertyPost
    |> where([rp], rp.archived == false and not is_nil(rp.assigned_owner_id))
    |> where([rp], ^end_time >= fragment("ROUND(extract(epoch from ?))", rp.expires_in))
    |> where([rp], rp.id in ^list_resale_post_ids_whatsapp_msg_deliver)
    |> Repo.all()
    |> Repo.preload([:building, :configuration_type, :assigned_owner])
    |> Enum.with_index()
    |> Enum.map(fn {post, index} ->
      notify_owner(post, index, "resale")
      Process.sleep(500)
    end)
  end

  def notify_owner(post, index, post_type) do
    if not is_nil(post.assigned_owner) do
      owner_phone_number = post.assigned_owner.phone_number |> Posts.get_phone_number_with_country_code()
      owner_name = String.trim(post.assigned_owner.name)
      building_name = String.trim(post.building.name)
      button_reply_payload = Posts.get_whatsapp_button_reply_payload_for_refresh_archive(post_type, post.uuid)
      post_map = Posts.post_map(post_type)

      Exq.enqueue(
        Exq,
        "send_sms",
        BnApis.Whatsapp.SendWhatsappMessageWorker,
        [
          owner_phone_number,
          Posts.expiry_reminder_mssg_template(post_type),
          [owner_name, building_name],
          %{"entity_type" => post_map.table, "entity_id" => post.id},
          true,
          button_reply_payload
        ]
      )

      IO.puts("Index- #{index}, entity_type - #{post_map.table}, entity_id - #{post.id}")
    end
  end
end
