defmodule BnApis.Commercial.CommercialAvailabilityNotification do
  import Ecto.Query

  alias BnApis.Repo
  alias BnApis.Commercials.CommercialPropertyPost
  alias BnApis.Commercials.CommercialPropertyPocMapping
  alias BnApis.Commercials.CommercialPropertyPostLog
  alias BnApis.Helpers.ApplicationHelper
  alias BnApis.Buildings.Building
  alias BnApis.Places.Polygon

  @check_for_activation_in_days 30
  @active "ACTIVE"
  @template "comm_check"

  def perform() do
    channel = ApplicationHelper.get_slack_channel()

    ApplicationHelper.notify_on_slack(
      "Starting to send commercial post availability message",
      channel
    )

    get_posts_for_activation_msg(@check_for_activation_in_days)
    |> Enum.each(fn post ->
      notify_pocs(post)
    end)

    ApplicationHelper.notify_on_slack(
      "Finished to to send commercial post availability message",
      channel
    )
  end

  def get_posts_for_activation_msg(days) do
    activation_date = Timex.now() |> Timex.Timezone.convert("Asia/Kolkata") |> Timex.shift(days: -1 * days)
    activation_date_start = activation_date |> Timex.beginning_of_day() |> Timex.Timezone.convert("UTC")
    activation_date_end = activation_date |> Timex.end_of_day() |> Timex.Timezone.convert("UTC")
    city_ids = CommercialPropertyPost.get_city_ids_for_reminder()

    latest_active_post_ids =
      CommercialPropertyPostLog
      |> join(:inner, [c], cp in CommercialPropertyPost, on: cp.id == c.commercial_property_post_id and cp.status == ^@active)
      |> where([c], fragment("(changes ->> 'status') = 'ACTIVE'"))
      |> where([c], c.inserted_at >= ^activation_date_start)
      |> group_by([c], c.commercial_property_post_id)
      |> select([c], %{post_id: c.commercial_property_post_id, inserted_at: max(c.inserted_at)})
      |> Repo.all()
      |> Enum.filter(fn x -> NaiveDateTime.compare(x.inserted_at, activation_date_end) in [:lt, :eq] end)
      |> Enum.map(& &1.post_id)

    CommercialPropertyPost
    |> join(:inner, [c], b in Building, on: c.building_id == b.id)
    |> join(:inner, [c, b], p in Polygon, on: b.polygon_id == p.id)
    |> where([c, b, p], c.id in ^latest_active_post_ids and c.status == @active and p.city_id in ^city_ids)
    |> Repo.all()
    |> Repo.preload(building: [:polygon])
  end

  def notify_pocs(post) do
    CommercialPropertyPocMapping.get_commercial_poc_details(post.id)
    |> Enum.each(fn p ->
      phone_number = p.country_code <> p.phone
      values = CommercialPropertyPost.get_post_details_for_whatsapp_message(post, p.name)
      button_reply_payload = CommercialPropertyPost.get_whatsapp_button_reply_payload(post.id)

      Exq.enqueue(Exq, "send_sms", BnApis.Whatsapp.SendWhatsappMessageWorker, [
        phone_number,
        @template,
        values,
        %{"entity_type" => CommercialPropertyPost.get_schema_name(), "entity_id" => post.id},
        true,
        button_reply_payload
      ])
    end)
  end
end
