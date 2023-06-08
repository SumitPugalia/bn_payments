defmodule BnApis.Commercial.CommercialAvailabilityResponseNotification do
  import Ecto.Query

  alias BnApis.Repo
  alias BnApis.Repo
  alias BnApis.Commercials.CommercialPropertyPost
  alias BnApis.Commercials.CommercialPropertyPocMapping
  alias BnApis.Whatsapp.WhatsappRequest
  alias BnApis.Helpers.ApplicationHelper
  alias BnApis.Buildings.Building
  alias BnApis.Places.Polygon

  @check_for_activation_in_days 30
  @active "ACTIVE"
  @template "comm_check"
  @template_availabilty_yes "comm_avail_yes"

  def perform() do
    channel = ApplicationHelper.get_slack_channel()

    ApplicationHelper.notify_on_slack(
      "Starting to send commercial post availability message after first msg",
      channel
    )

    get_post_ids_to_send_notification(@check_for_activation_in_days)
    |> Enum.each(fn post_id ->
      send_reminder(post_id)
    end)

    ApplicationHelper.notify_on_slack(
      "Finished to send commercial post availability message after first msg",
      channel
    )
  end

  def get_post_ids_to_send_notification(days) do
    activation_date =
      Timex.now()
      |> Timex.Timezone.convert("Asia/Kolkata")
      |> Timex.shift(days: -1 * days)

    activation_date_start = activation_date |> Timex.beginning_of_day() |> Timex.Timezone.convert("UTC")
    activation_date_end = activation_date |> Timex.end_of_day() |> Timex.Timezone.convert("UTC")
    city_ids = CommercialPropertyPost.get_city_ids_for_reminder()

    active_post_ids =
      CommercialPropertyPost
      |> join(:inner, [c], b in Building, on: c.building_id == b.id)
      |> join(:inner, [c, b], p in Polygon, on: b.polygon_id == p.id)
      |> where([c, b, p], c.status == ^@active and p.city_id in ^city_ids)
      |> select([c, b, p], c.id)
      |> Repo.all()

    WhatsappRequest
    |> where([w], w.entity_type == ^CommercialPropertyPost.get_schema_name() and w.entity_id in ^active_post_ids)
    |> where([w], w.inserted_at >= ^activation_date_start and w.inserted_at <= ^activation_date_end)
    |> where([w], w.status in ^["read", "delivered"] and w.template == ^@template_availabilty_yes)
    |> distinct([w], w.entity_id)
    |> select([w], w.entity_id)
    |> Repo.all()
  end

  def send_reminder(post_id) do
    post =
      Repo.get_by(CommercialPropertyPost, id: post_id)
      |> Repo.preload(building: [:polygon])

    CommercialPropertyPocMapping.get_commercial_poc_details(post_id)
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
