defmodule BnApis.Posts.PushLeadForOwnerNotRegisteredOnWhatsapp do
  alias BnApis.Repo

  alias BnApis.Posts
  alias BnApis.Whatsapp.WhatsappRequest
  alias BnApis.Helpers.SlashHelper
  alias BnApis.Posts.PostLeads
  alias BnApis.WorkerHelper

  import Ecto.Query
  @rent Posts.rent()
  @resale Posts.resale()

  def perform() do
    push_expired_post_leads()
  end

  def push_expired_post_leads() do
    today = Timex.now() |> Timex.Timezone.convert("Asia/Kolkata")
    start_time_unix = today |> Timex.beginning_of_day() |> DateTime.to_unix()
    end_time_unix = today |> Timex.end_of_day() |> DateTime.to_unix()

    # This cron needs to be triggered after approximately 3 hours of the running time of BnApis.Posts.NotifyExpiringPostsCronWorker
    # So we can trigger this at 12 P.M IST

    expiry_post_templates = [Posts.expiry_mssg_template(@rent), Posts.expiry_mssg_template(@resale)]

    WhatsappRequest
    |> where([wr], wr.status == ^WhatsappRequest.not_sent_status() and wr.template in ^expiry_post_templates)
    |> where(
      [wr],
      ^start_time_unix <= fragment("ROUND(extract(epoch from ?))", wr.inserted_at) and
        ^end_time_unix >= fragment("ROUND(extract(epoch from ?))", wr.inserted_at)
    )
    |> select([wr], %{
      phone_number: wr.to,
      entity_type: wr.entity_type,
      entity_id: wr.entity_id
    })
    |> Repo.all()
    |> Enum.each(fn record ->
      process_record(record)
    end)
  end

  def process_record(record) do
    rent_map = Posts.post_map(@rent)
    resale_map = Posts.post_map(@resale)
    source = SlashHelper.expired_posts()
    emp = WorkerHelper.get_bot_employee_credential()

    cond do
      record.entity_type == rent_map.table ->
        create_lead_using_post_map(rent_map, record.entity_id, source, emp.id)

      record.entity_type == resale_map.table ->
        create_lead_using_post_map(resale_map, record.entity_id, source, emp.id)
    end
  end

  def create_lead_using_post_map(post_map, entity_id, source, emp_id) do
    post = Repo.get_by(post_map.module, id: entity_id)
    post = Repo.preload(post, :assigned_owner)
    post_lead_params = get_lead_params(post.uuid, post_map.type, source, emp_id, post.assigned_owner)
    PostLeads.create_lead_and_push_to_slash(post_lead_params)
  end

  def get_lead_params(post_uuid, post_type, source, emp_id, owner) when not is_nil(owner) do
    %{
      post_type: post_type,
      post_uuid: post_uuid,
      source: source,
      country_code: owner.country_code,
      phone_number: owner.phone_number,
      created_by_employee_id: emp_id
    }
  end
end
