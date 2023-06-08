defmodule BnApis.Posts.NotifyExpiringPostsCronWorker do
  alias BnApis.Repo

  alias BnApis.Posts
  alias BnApis.Posts.RentalPropertyPost
  alias BnApis.Posts.ResalePropertyPost

  import Ecto.Query

  def perform() do
    notify_expiring_posts()
  end

  def notify_expiring_posts() do
    tomorrow = Timex.now() |> Timex.Timezone.convert("Asia/Kolkata") |> Timex.shift(days: 1)
    tomorrow_start = tomorrow |> Timex.beginning_of_day() |> DateTime.to_unix()
    tomorrow_end = tomorrow |> Timex.end_of_day() |> DateTime.to_unix()

    RentalPropertyPost
    |> where([rp], rp.archived == false and not is_nil(rp.assigned_owner_id))
    |> where(
      [rp],
      ^tomorrow_start <= fragment("ROUND(extract(epoch from ?))", rp.expires_in) and
        ^tomorrow_end >= fragment("ROUND(extract(epoch from ?))", rp.expires_in)
    )
    |> Repo.all()
    |> Repo.preload([:building, :configuration_type, :furnishing_type, :assigned_owner])
    |> Enum.each(fn post ->
      notify_owner(post, "rent")
      Process.sleep(500)
    end)

    ResalePropertyPost
    |> where([rp], rp.archived == false and not is_nil(rp.assigned_owner_id))
    |> where(
      [rp],
      ^tomorrow_start <= fragment("ROUND(extract(epoch from ?))", rp.expires_in) and
        ^tomorrow_end >= fragment("ROUND(extract(epoch from ?))", rp.expires_in)
    )
    |> Repo.all()
    |> Repo.preload([:building, :configuration_type, :assigned_owner])
    |> Enum.each(fn post ->
      notify_owner(post, "resale")
      Process.sleep(500)
    end)
  end

  def notify_owner(post, post_type) do
    if not is_nil(post.assigned_owner) do
      owner_phone_number = post.assigned_owner.phone_number |> Posts.get_phone_number_with_country_code()
      values = Posts.get_post_details_for_whatsapp_message(post, post_type)
      button_reply_payload = Posts.get_whatsapp_button_reply_payload_for_refresh_archive(post_type, post.uuid)
      post_map = Posts.post_map(post_type)

      Exq.enqueue(
        Exq,
        "send_sms",
        BnApis.Whatsapp.SendWhatsappMessageWorker,
        [
          owner_phone_number,
          Posts.expiry_mssg_template(post_type),
          values,
          %{"entity_type" => post_map.table, "entity_id" => post.id},
          true,
          button_reply_payload
        ]
      )
    end
  end
end
