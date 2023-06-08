defmodule BnApis.Posts.SendReminderForExpiringPostsCronWorker do
  alias BnApis.Repo

  alias BnApis.Posts
  alias BnApis.Posts.RentalPropertyPost
  alias BnApis.Posts.ResalePropertyPost
  alias BnApis.Posts.PostLeads
  alias BnApis.Accounts.Owner
  alias BnApis.Helpers.SlashHelper
  alias BnApis.WorkerHelper
  alias BnApis.Posts.ReportedRentalPropertyPost
  alias BnApis.Posts.ReportedResalePropertyPost
  alias BnApis.Helpers.Time

  import Ecto.Query

  def perform() do
    send_reminder_for_expiring_posts()
  end

  def send_reminder_for_expiring_posts() do
    first_reminder_start_time_unix = Time.get_start_time_in_unix(-3)
    first_reminder_end_time_unix = Time.get_end_time_in_unix(-3)

    second_reminder_start_time_unix = Time.get_start_time_in_unix(-6)
    second_reminder_end_time_unix = Time.get_end_time_in_unix(-6)

    send_reminder_mssg_for_expired_posts(
      RentalPropertyPost,
      "rent",
      first_reminder_start_time_unix,
      first_reminder_end_time_unix,
      [:building, :configuration_type, :furnishing_type, :assigned_owner]
    )

    send_reminder_mssg_for_expired_posts(
      ResalePropertyPost,
      "resale",
      first_reminder_start_time_unix,
      first_reminder_end_time_unix,
      [:building, :configuration_type, :assigned_owner]
    )

    send_reminder_mssg_for_expired_posts(
      RentalPropertyPost,
      "rent",
      second_reminder_start_time_unix,
      second_reminder_end_time_unix,
      [:building, :configuration_type, :furnishing_type, :assigned_owner]
    )

    send_reminder_mssg_for_expired_posts(
      ResalePropertyPost,
      "resale",
      second_reminder_start_time_unix,
      second_reminder_end_time_unix,
      [:building, :configuration_type, :assigned_owner]
    )

    expired_post_slash_start_time_unix = Time.get_start_time_in_unix(-7)
    expired_post_slash_end_time_unix = Time.get_end_time_in_unix(-7)

    reported_post_slash_start_time_unix = Time.get_start_time_in_unix(-1)
    reported_post_slash_end_time_unix = Time.get_end_time_in_unix(-1)

    expired_lead_source = SlashHelper.expired_posts()
    reported_lead_source = SlashHelper.reported_posts()
    cron_emp = WorkerHelper.get_bot_employee_credential()

    push_expired_posts_to_slash(RentalPropertyPost, "rent", expired_post_slash_start_time_unix, expired_post_slash_end_time_unix, expired_lead_source, cron_emp.id)
    push_expired_posts_to_slash(ResalePropertyPost, "resale", expired_post_slash_start_time_unix, expired_post_slash_end_time_unix, expired_lead_source, cron_emp.id)
    push_reported_posts_to_slash("rent", reported_post_slash_start_time_unix, reported_post_slash_end_time_unix, reported_lead_source, cron_emp.id)
    push_reported_posts_to_slash("resale", reported_post_slash_start_time_unix, reported_post_slash_end_time_unix, reported_lead_source, cron_emp.id)
  end

  def push_expired_posts_to_slash(post_class, post_type, start_time_unix, end_time_unix, source, emp_id) do
    post_class
    |> join(:inner, [rp], o in Owner, on: rp.assigned_owner_id == o.id)
    |> where([rp, o], rp.archived == false)
    |> where(
      [rp, o],
      ^start_time_unix <= fragment("ROUND(extract(epoch from ?))", rp.expires_in) and
        ^end_time_unix >= fragment("ROUND(extract(epoch from ?))", rp.expires_in)
    )
    |> select([rp, o], %{
      post_uuid: rp.uuid,
      country_code: o.country_code,
      phone_number: o.phone_number
    })
    |> Repo.all()
    |> Enum.map(fn post_lead_params -> add_post_type_and_emp_id(post_lead_params, post_type, source, emp_id) end)
    |> Enum.each(fn post_lead_params -> PostLeads.create_lead_and_push_to_slash(post_lead_params) end)
  end

  def push_reported_posts_to_slash(post_type, start_time_unix, end_time_unix, source, emp_id) when post_type == "rent" do
    ReportedRentalPropertyPost
    |> join(:inner, [rrp], rp in RentalPropertyPost, on: rrp.rental_property_id == rp.id)
    |> where([rrp, rp], is_nil(rrp.refreshed_on) or fragment("ROUND(extract(epoch from ?))", rrp.refreshed_on) < ^start_time_unix)
    |> where(
      [rrp, rp],
      ^start_time_unix <= fragment("ROUND(extract(epoch from ?))", rrp.inserted_at) and
        ^end_time_unix >= fragment("ROUND(extract(epoch from ?))", rrp.inserted_at)
    )
    |> join(:inner, [rrp, rp], o in Owner, on: rp.assigned_owner_id == o.id)
    |> select([rrp, rp, o], %{
      post_uuid: rp.uuid,
      country_code: o.country_code,
      phone_number: o.phone_number
    })
    |> distinct(true)
    |> Repo.all()
    |> Enum.map(fn post_lead_params -> add_post_type_and_emp_id(post_lead_params, post_type, source, emp_id) end)
    |> Enum.each(fn post_lead_params -> PostLeads.create_lead_and_push_to_slash(post_lead_params) end)
  end

  def push_reported_posts_to_slash(post_type, start_time_unix, end_time_unix, source, emp_id) when post_type == "resale" do
    ReportedResalePropertyPost
    |> join(:inner, [rrp], rp in ResalePropertyPost, on: rrp.resale_property_id == rp.id)
    |> where([rrp, rp], is_nil(rrp.refreshed_on) or fragment("ROUND(extract(epoch from ?))", rrp.refreshed_on) < ^start_time_unix)
    |> where(
      [rrp, rp],
      ^start_time_unix <= fragment("ROUND(extract(epoch from ?))", rrp.inserted_at) and
        ^end_time_unix >= fragment("ROUND(extract(epoch from ?))", rrp.inserted_at)
    )
    |> join(:inner, [rrp, rp], o in Owner, on: rp.assigned_owner_id == o.id)
    |> select([rrp, rp, o], %{
      post_uuid: rp.uuid,
      country_code: o.country_code,
      phone_number: o.phone_number
    })
    |> distinct(true)
    |> Repo.all()
    |> Enum.map(fn post_lead_params -> add_post_type_and_emp_id(post_lead_params, post_type, source, emp_id) end)
    |> Enum.each(fn post_lead_params -> PostLeads.create_lead_and_push_to_slash(post_lead_params) end)
  end

  def add_post_type_and_emp_id(post_lead_params, post_type, source, emp_id) do
    post_lead_params
    |> Map.merge(%{
      post_type: post_type,
      source: source,
      created_by_employee_credential_id: emp_id
    })
  end

  def send_reminder_mssg_for_expired_posts(post_class, post_type, start_time_unix, end_time_unix, preload_list) do
    post_class
    |> where([rp], rp.archived == false and not is_nil(rp.assigned_owner_id))
    |> where(
      [rp],
      ^start_time_unix <= fragment("ROUND(extract(epoch from ?))", rp.expires_in) and
        ^end_time_unix >= fragment("ROUND(extract(epoch from ?))", rp.expires_in)
    )
    |> Repo.all()
    |> Repo.preload(preload_list)
    |> Enum.each(fn post ->
      notify_owner(post, post_type)
      Process.sleep(500)
    end)
  end

  defp notify_owner(post, post_type) do
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
    end
  end
end
