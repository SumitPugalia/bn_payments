defmodule Mix.Tasks.SendWhatsappMessageForAllExpiredResalePosts do
  use Mix.Task

  alias BnApis.Repo

  alias BnApis.Posts
  alias BnApis.Posts.ResalePropertyPost

  import Ecto.Query

  def run(_) do
    Mix.Task.run("app.start", [])
    notify_expired_posts()
  end

  def notify_expired_posts() do
    start_time =
      Timex.now()
      |> Timex.Timezone.convert("Asia/Kolkata")
      |> Timex.beginning_of_day()
      |> Timex.shift(days: -90)
      |> DateTime.to_unix()

    end_time = Timex.now() |> DateTime.to_unix()

    ResalePropertyPost
    |> where([rp], rp.archived == false and not is_nil(rp.assigned_owner_id))
    |> where(
      [rp],
      ^start_time <= fragment("ROUND(extract(epoch from ?))", rp.expires_in) and
        ^end_time >= fragment("ROUND(extract(epoch from ?))", rp.expires_in)
    )
    |> Repo.all()
    |> Repo.preload([:building, :configuration_type, :assigned_owner])
    |> Enum.each(fn post ->
      notify_owner(post, "resale")
      Process.sleep(1000)
    end)
  end

  def notify_owner(post, post_type) do
    if not is_nil(post.assigned_owner) do
      owner_phone_number = post.assigned_owner.phone_number |> Posts.get_phone_number_with_country_code()
      values = Posts.get_post_details_for_whatsapp_message(post, post_type)
      button_reply_payload = Posts.get_whatsapp_button_reply_payload_for_refresh_archive(post_type, post.uuid)

      Exq.enqueue(
        Exq,
        "send_sms",
        BnApis.Whatsapp.SendWhatsappMessageWorker,
        [
          owner_phone_number,
          Posts.expiry_mssg_template(post_type),
          values,
          %{},
          true,
          button_reply_payload
        ]
      )
    end
  end
end
