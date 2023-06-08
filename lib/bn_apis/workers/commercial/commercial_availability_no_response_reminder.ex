defmodule BnApis.Commercial.CommercialAvailabilityNoResponseReminder do
  import Ecto.Query

  alias BnApis.Repo
  alias BnApis.Commercials.CommercialPropertyPost
  alias BnApis.Commercials.CommercialPropertyPocMapping
  alias BnApis.Places.City
  alias BnApis.Whatsapp.WhatsappRequest
  alias BnApis.Helpers.ApplicationHelper
  alias BnApis.Buildings.Building
  alias BnApis.Places.Polygon

  # @active "ACTIVE"
  @first_reminder_days 2
  @second_reminder_days 5
  @availbity_check_reminder "comm_check"
  @availbity_check_reminder_yes "comm_avail_yes"
  @availbity_check_reminder_no "comm_avail_no"
  @first_reminder_template "remind_1"
  @second_reminder_template "remind_2"
  @active "ACTIVE"

  def perform() do
    msg_ids_for_1st_rem = un_responded_msg_ids(@first_reminder_days)
    msg_ids_for_2st_rem = un_responded_msg_ids(@second_reminder_days)

    channel = ApplicationHelper.get_slack_channel()

    ApplicationHelper.notify_on_slack(
      "Starting to send commercial post availability 1st reminder",
      channel
    )

    msg_ids_for_1st_rem
    |> Enum.each(fn post_id ->
      send_reminder(post_id, @first_reminder_template)
    end)

    ApplicationHelper.notify_on_slack(
      "Finished to send commercial post availability 1st reminder",
      channel
    )

    ApplicationHelper.notify_on_slack(
      "Starting to send commercial post availability 2nd reminder",
      channel
    )

    msg_ids_for_2st_rem
    |> Enum.each(fn post_id ->
      send_reminder(post_id, @second_reminder_template)
    end)

    ApplicationHelper.notify_on_slack(
      "Finished to send commercial post availability 2nd reminder",
      channel
    )
  end

  def un_responded_msg_ids(days) do
    activation_date = Timex.now() |> Timex.Timezone.convert("Asia/Kolkata") |> Timex.shift(days: -1 * days)
    activation_date_start = activation_date |> Timex.beginning_of_day() |> Timex.Timezone.convert("UTC")
    activation_date_end = activation_date |> Timex.end_of_day() |> Timex.Timezone.convert("UTC")
    entity_type = CommercialPropertyPost.get_schema_name()
    city_ids = CommercialPropertyPost.get_city_ids_for_reminder()

    active_post_ids =
      CommercialPropertyPost
      |> join(:inner, [c], b in Building, on: c.building_id == b.id)
      |> join(:inner, [c, b], p in Polygon, on: b.polygon_id == p.id)
      |> where([c, b, p], c.status == ^@active and p.city_id in ^city_ids)
      |> select([c, b, p], c.id)
      |> Repo.all()

    send_msg_post_ids =
      WhatsappRequest
      |> where([w], w.entity_type == ^entity_type and w.template == ^@availbity_check_reminder)
      |> where([w], w.inserted_at >= ^activation_date_start and w.inserted_at <= ^activation_date_end)
      |> where([w], w.entity_id in ^active_post_ids)
      |> select([w], w.entity_id)
      |> Repo.all()

    responded_post_ids =
      WhatsappRequest
      |> where([w], w.entity_type == ^entity_type and w.entity_id in ^send_msg_post_ids)
      |> where([w], w.inserted_at >= ^activation_date_start)
      |> where([w], w.template in ^[@availbity_check_reminder_no, @availbity_check_reminder_yes])
      |> select([w], w.entity_id)
      |> Repo.all()

    send_msg_post_ids -- responded_post_ids
  end

  def send_reminder(post_id, template_name) do
    post =
      Repo.get_by(CommercialPropertyPost, id: post_id)
      |> Repo.preload(building: [:polygon])

    CommercialPropertyPocMapping.get_commercial_poc_details(post_id)
    |> Enum.each(fn p ->
      phone_number = p.country_code <> p.phone
      values = get_post_details_for_whatsapp_message(post, p.name)
      button_reply_payload = CommercialPropertyPost.get_whatsapp_button_reply_payload(post.id)

      Exq.enqueue(Exq, "send_sms", BnApis.Whatsapp.SendWhatsappMessageWorker, [
        phone_number,
        template_name,
        values,
        %{"entity_type" => CommercialPropertyPost.get_schema_name(), "entity_id" => post.id},
        true,
        button_reply_payload
      ])
    end)
  end

  def get_post_details_for_whatsapp_message(post, poc_name) do
    city = City.get_city_by_id(post.building.polygon.city_id)

    [
      "#{poc_name}",
      "#{post.building.polygon.name}",
      "#{city.name} (#{post.google_maps_url})",
      "#{CommercialPropertyPost.get_post_type(post.is_available_for_lease, post.is_available_for_purchase)}"
    ]
  end
end
