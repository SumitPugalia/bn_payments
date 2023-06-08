defmodule BnApis.Commercials.CommercialSiteVisit do
  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query

  alias BnApis.Repo
  alias BnApis.Commercials.CommercialPropertyPost
  alias BnApis.Organizations.Broker
  alias BnApis.Commercials.CommercialSiteVisit
  alias BnApis.Commercials.CommercialsEnum
  alias BnApis.Helpers.Time
  alias BnApis.Accounts.EmployeeCredential
  alias BnApis.Reasons.Reason
  alias BnApis.Accounts.Credential
  alias BnApis.Organizations.Organization
  alias BnApis.Places.Polygon
  alias BnApis.Commercials.CommercialChannelUrlMapping
  alias BnApis.Helpers.Utils

  @visit_scheduled "SCHEDULED"
  @visit_completed "COMPLETED"
  @visit_cancelled "CANCELLED"
  @visit_deleted "DELETED"
  @active_post_status "ACTIVE"
  @commercial_site_vist_schema_name "commercial_site_visits"

  schema "commercial_site_visits" do
    field :visit_status, :string
    field :visit_date, :integer
    field :created_at, :integer
    field :visit_remarks, :string
    field :is_active, :boolean, default: true

    belongs_to(:commercial_property_post, CommercialPropertyPost)
    belongs_to(:cancelled_by, EmployeeCredential)
    belongs_to(:completed_by, EmployeeCredential)
    belongs_to(:reason, Reason)
    belongs_to(:broker, Broker)
    timestamps()
  end

  @required [:visit_status, :visit_date, :is_active, :commercial_property_post_id, :broker_id, :created_at]
  @optional [:cancelled_by_id, :completed_by_id, :reason_id, :visit_remarks]
  def changeset(commercial_site_visit, attrs) do
    commercial_site_visit
    |> cast(attrs, @required ++ @optional)
    |> validate_required(@required)
  end

  def get_schema_name(), do: @commercial_site_vist_schema_name

  def list_site_visits(params) do
    {query, content_query, page_no, size} = CommercialSiteVisit.filter_query(params)

    site_visits =
      content_query
      |> order_by([v, c, b], desc: v.inserted_at)
      |> Repo.all()
      |> Repo.preload([:broker, commercial_property_post: [:building]])
      |> Enum.map(fn site_visit -> get_site_visit_properties(site_visit) end)

    total_count = query |> distinct(:id) |> Repo.aggregate(:count, :id)
    next_page_exists = page_no < Float.ceil(total_count / size)

    response = %{
      "site_visits" => site_visits,
      "has_more" => next_page_exists,
      "total_count" => total_count,
      "next_page_query_params" => "p=#{page_no + 1}"
    }

    {:ok, response}
  end

  def list_site_visits_for_broker(page, limit, status, visit_start_time, visit_end_time, status_ids, broker_id, user_id, app_version \\ nil) do
    {page_no, page_size, total_count, post_uuids} = CommercialSiteVisit.get_post_ids_of_visits(page, limit, status, visit_start_time, visit_end_time, status_ids, broker_id)

    commercial_posts =
      post_uuids
      |> Enum.map(fn r ->
        {:ok, post} = CommercialPropertyPost.get_post(r, user_id, status, app_version)
        post
      end)

    next_page_exists = page_no < Float.ceil(total_count / page_size)

    response = %{
      "commercial_posts" => commercial_posts,
      "has_more" => next_page_exists,
      "total_count" => total_count,
      "next_page_query_params" => "p=#{page_no + 1}"
    }

    {:ok, response}
  end

  def get_post_ids_of_visits(page_no, page_size, status, visit_start_time, visit_end_time, status_ids, broker_id) do
    query =
      CommercialSiteVisit
      |> join(:inner, [v], c in CommercialPropertyPost, on: c.id == v.commercial_property_post_id and c.status == ^@active_post_status)
      |> join(:inner, [v, c], b in Broker, on: b.id == v.broker_id)
      |> distinct([v, c, b], v.commercial_property_post_id)
      |> where([v, c, b], v.broker_id == ^broker_id)
      |> where([v, c, b], v.is_active == ^true)

    query =
      if(not is_nil(visit_start_time) and not is_nil(visit_end_time) and visit_start_time > 0 and visit_end_time > 0) do
        query |> where([v, c, b], fragment("? BETWEEN ? AND ?", v.visit_date, ^visit_end_time, ^visit_end_time))
      else
        query
      end

    query =
      if(not is_nil(status_ids) and is_list(status_ids) and length(status_ids) > 0) do
        valid_status_ids = CommercialsEnum.validate_commercial_enum_ids(status_ids)
        status_ids = valid_status_ids |> Enum.map(&CommercialsEnum.get_visit_status_identifier_from_id(&1))
        query |> where([v, c, b], v.visit_status in ^status_ids)
      else
        query |> where([v, c, b], v.visit_status == ^status)
      end

    total_count = query |> Repo.all() |> Enum.map(& &1.id) |> length

    post_uuids =
      query
      |> limit(^page_size)
      |> offset(^((page_no - 1) * page_size))
      |> Repo.all()
      |> Repo.preload([:commercial_property_post])
      |> Enum.map(fn r -> r.commercial_property_post.uuid end)

    {page_no, page_size, total_count, post_uuids}
  end

  def get_site_visit(params, site_visit) do
    params = params |> Map.merge(%{"visit_id" => site_visit.id})
    {_query, content_query, _page_no, _size} = CommercialSiteVisit.filter_query(params)

    [site_visit] =
      content_query
      |> order_by([v, c, b], desc: v.inserted_at)
      |> Repo.all()
      |> Repo.preload([:broker, commercial_property_post: [:building]])
      |> Enum.map(fn site_visit -> site_visit end)

    {:ok, site_visit}
  end

  defp get_site_visit_properties(site_visit) do
    cred = Credential.get_credential_from_broker_id(site_visit.broker_id)

    organisation = if not is_nil(cred.organization_id), do: Organization |> Repo.get_by(id: cred.organization_id), else: nil

    polygon =
      if not is_nil(site_visit.broker.polygon_id),
        do: Polygon |> Repo.get_by(id: site_visit.broker.polygon_id),
        else: nil

    channel_url = CommercialChannelUrlMapping.get_commercial_url(site_visit.commercial_property_post_id, site_visit.broker_id)

    response = %{
      "visit_id" => site_visit.id,
      "visit_status" => site_visit.visit_status,
      "visit_date" => site_visit.visit_date,
      "visit_remarks" => site_visit.visit_remarks,
      "created_at" => site_visit.created_at,
      "is_active" => site_visit.is_active,
      "commercial_property_post_id" => site_visit.commercial_property_post_id,
      "commercial_property_post_uuid" => site_visit.commercial_property_post.uuid,
      "broker_id" => site_visit.broker_id,
      "broker_name" => site_visit.broker.name,
      "broker_phone_number" => cred.phone_number,
      "cancelled_by_id" => site_visit.cancelled_by_id,
      "completed_by_id" => site_visit.completed_by_id,
      "reason_id" => site_visit.reason_id,
      "operating_city" => site_visit.broker.operating_city,
      "building_display_address" => site_visit.commercial_property_post.building.display_address,
      "building_name" => site_visit.commercial_property_post.building.name,
      "grade" => site_visit.commercial_property_post.building.grade,
      "google_maps_url" => site_visit.commercial_property_post.google_maps_url,
      "polygon_name" => if(not is_nil(polygon), do: polygon.name, else: nil),
      "organisation_name" => if(not is_nil(organisation), do: organisation.name, else: nil),
      "floor_plate" => site_visit.commercial_property_post.floor_plate,
      "unit_number" => site_visit.commercial_property_post.unit_number,
      "channel_url" => channel_url
    }

    cond do
      site_visit.visit_status == @visit_cancelled and not is_nil(site_visit.cancelled_by_id) ->
        emp_cred = EmployeeCredential |> Repo.get_by(id: site_visit.cancelled_by_id)
        response |> Map.merge(%{"cancelled_by_name" => emp_cred.name})

      site_visit.visit_status == @visit_completed and not is_nil(site_visit.completed_by_id) ->
        emp_cred = EmployeeCredential |> Repo.get_by(id: site_visit.completed_by_id)
        response |> Map.merge(%{"completed_by_name" => emp_cred.name})

      site_visit.visit_status == @visit_deleted and not is_nil(site_visit.reason_id) ->
        reason = Reason |> Repo.get_by(id: site_visit.reason_id)
        response |> Map.merge(%{"reason" => reason.name})

      true ->
        response
    end
  end

  def filter_query(params) do
    page_no = (params["p"] || "1") |> String.to_integer()
    size = (params["size"] || "20") |> String.to_integer()

    query =
      CommercialSiteVisit
      |> join(:inner, [v], c in CommercialPropertyPost, on: c.id == v.commercial_property_post_id)
      |> join(:inner, [v, c], b in Broker, on: b.id == v.broker_id)

    query =
      if not is_nil(params["status_id"]) do
        status_id = if is_binary(params["status_id"]), do: String.to_integer(params["status_id"]), else: params["status_id"]

        status = CommercialsEnum.get_visit_status_identifier_from_id(status_id)
        query |> where([v, c, b], v.visit_status == ^status)
      else
        query
      end

    query =
      if not is_nil(params["commercial_post_id"]) do
        commercial_post_id = Utils.parse_to_integer(params["commercial_post_id"])
        query |> where([v, c, b], c.id == ^commercial_post_id)
      else
        query
      end

    query =
      if not is_nil(params["is_commercial_agent"]) and params["is_commercial_agent"] == true do
        query |> where([v, c, b], c.assigned_manager_id == ^params["assigned_manager_id"])
      else
        query
      end

    query =
      if not is_nil(params["is_commercial_agent"]) do
        query |> where([v, c, b], c.status == ^@active_post_status)
      else
        query
      end

    query =
      if not is_nil(params["visit_id"]) do
        status_id = Utils.parse_to_integer(params["visit_id"])
        query |> where([v, c, b], v.id == ^status_id)
      else
        query
      end

    query =
      if not is_nil(params["is_active"]) do
        is_active = if is_binary(params["is_active"]), do: params["is_active"] == "true", else: params["is_active"]
        query |> where([v, c, b], v.is_active == ^is_active)
      else
        query |> where([v, c, b], v.is_active == ^true)
      end

    query =
      if not is_nil(params["broker_name"]) do
        broker_name = params["broker_name"]
        formatted_query = "%#{String.downcase(String.trim(broker_name))}%"
        query |> where([v, c, b], fragment("LOWER(?) LIKE ?", b.name, ^formatted_query))
      else
        query
      end

    query =
      if not is_nil(params["visit_date"]) do
        filter_visit_date(query, params["visit_date"])
      else
        query
      end

    content_query =
      query
      |> limit(^size)
      |> offset(^((page_no - 1) * size))

    {query, content_query, page_no, size}
  end

  defp filter_visit_date(query, visit_date) do
    visit_date = Utils.parse_to_integer(visit_date)
    {:ok, unix_date_time} = DateTime.from_unix(visit_date)
    vd = unix_date_time |> Timex.to_date() |> Timex.to_datetime("Asia/Kolkata") |> Timex.Timezone.convert("Etc/UTC")
    start_time = vd |> Timex.beginning_of_day() |> Timex.to_datetime() |> DateTime.to_unix()
    end_time = vd |> Timex.end_of_day() |> Timex.to_datetime() |> DateTime.to_unix()
    query |> where([v, c, b], fragment("? BETWEEN ? AND ?", v.visit_date, ^start_time, ^end_time))
  end

  def create_site_visit(params, broker_id) do
    current_time = Timex.now() |> Time.naive_to_epoch_in_sec()

    if params["visit_date"] > current_time do
      {:ok, site_visit} =
        CommercialSiteVisit.changeset(%CommercialSiteVisit{}, %{
          visit_status: @visit_scheduled,
          visit_date: params["visit_date"],
          visit_remarks: params["visit_remarks"],
          created_at: Timex.now() |> Time.naive_to_epoch_in_sec(),
          commercial_property_post_id: params["commercial_property_post_id"],
          broker_id: broker_id
        })
        |> Repo.insert()

      {:ok, site_visit.id}
    else
      {:error, "Site visits can only be scheduled for future time"}
    end
  end

  def update_site_visit(commercial_site_visit, params) do
    commercial_site_visit
    |> CommercialSiteVisit.changeset(params)
    |> Repo.update()
  end

  def get_all_visit_details_for_broker_id(broker_id, post_id) do
    CommercialSiteVisit
    |> join(:left, [cs], e1 in EmployeeCredential, on: e1.id == cs.cancelled_by_id)
    |> join(:left, [cs, e1], e2 in EmployeeCredential, on: e2.id == cs.completed_by_id)
    |> join(:left, [cs, e1, e2], r in Reason, on: r.id == cs.reason_id)
    |> where([cs, e1, e2, r], cs.broker_id == ^broker_id)
    |> where([cs, e1, e2, r], cs.commercial_property_post_id == ^post_id)
    |> order_by([cs, e1, e2, r], desc: cs.visit_date)
    |> select([cs, e1, e2, r], %{
      visit_id: cs.id,
      visit_status: cs.visit_status,
      visit_date: cs.visit_date,
      visit_remarks: cs.visit_remarks,
      created_at: cs.created_at,
      is_active: cs.is_active,
      commercial_property_post_id: cs.commercial_property_post_id,
      broker_id: cs.broker_id,
      cancelled_by_id: cs.cancelled_by_id,
      cancelled_by_name: e1.name,
      completed_by_id: cs.completed_by_id,
      completed_by_id: e2.name,
      reason_id: cs.reason_id,
      reason: r.name
    })
    |> Repo.all()
  end

  def get_last_visit_details_for_broker_id(@visit_scheduled = _status, broker_id, post_id, is_current_time_included) do
    current_time = NaiveDateTime.utc_now() |> Time.naive_to_epoch_in_sec()

    query =
      CommercialSiteVisit
      |> where([cs], cs.broker_id == ^broker_id)
      |> where([cs], cs.commercial_property_post_id == ^post_id)
      |> where([cs], cs.visit_status == ^@visit_scheduled)
      |> order_by([cs], asc: cs.visit_date)

    query =
      if is_current_time_included,
        do: query |> where([cs], cs.visit_date > ^current_time),
        else: query

    query
    |> select([cs], %{
      visit_status: cs.visit_status,
      visit_date: cs.visit_date,
      visit_remarks: cs.visit_remarks,
      created_at: cs.created_at,
      is_active: cs.is_active,
      commercial_property_post_id: cs.commercial_property_post_id,
      broker_id: cs.broker_id
    })
    |> Repo.all()
    |> List.first()
  end

  def get_last_visit_details_for_broker_id(@visit_completed = _status, broker_id, post_id, is_current_time_included) do
    current_time = NaiveDateTime.utc_now() |> Time.naive_to_epoch_in_sec()

    query =
      CommercialSiteVisit
      |> where([cs], cs.broker_id == ^broker_id)
      |> where([cs], cs.commercial_property_post_id == ^post_id)
      |> where([cs], cs.visit_status == ^@visit_completed)
      |> order_by([cs], desc: cs.visit_date)

    query =
      if is_current_time_included,
        do: query |> where([cs], cs.visit_date < ^current_time),
        else: query

    query
    |> select([cs], %{
      visit_status: cs.visit_status,
      visit_date: cs.visit_date,
      visit_remarks: cs.visit_remarks,
      created_at: cs.created_at,
      is_active: cs.is_active,
      commercial_property_post_id: cs.commercial_property_post_id,
      broker_id: cs.broker_id
    })
    |> Repo.all()
    |> List.first()
  end

  def get_nearest_commercial_post_visit_details(broker_id, post_id) do
    site_visits_scheduled = get_last_visit_details_for_broker_id(@visit_scheduled, broker_id, post_id, true)
    site_visits_completed = get_last_visit_details_for_broker_id(@visit_completed, broker_id, post_id, true)

    if is_nil(site_visits_scheduled) do
      site_visits_completed
    else
      site_visits_scheduled
    end
  end

  def aggregate_visits(params) do
    {query, _content_query, _page_no, _size} = CommercialSiteVisit.filter_query(params)
    total_visits = query |> Repo.all()

    planned_visit = total_visits |> Enum.filter(&(&1.visit_status == @visit_scheduled)) |> Enum.map(& &1.id) |> Enum.uniq() |> length

    completed_visit = total_visits |> Enum.filter(&(&1.visit_status == @visit_completed)) |> Enum.map(& &1.id) |> Enum.uniq() |> length

    %{
      "Planned" => planned_visit,
      "completed" => completed_visit,
      "total" => planned_visit + completed_visit
    }
  end

  def create_whatsapp_request_payload(broker_id, visit_date, property_details) do
    date_and_time = Time.get_formatted_datetime(visit_date, "%d/%m/%Y, %I:%M%p")
    credential = Credential.get_credential_from_broker_id(broker_id) |> Repo.preload([:broker])

    [
      "*#{property_details}*",
      "*#{date_and_time}*",
      "*#{credential.broker.name}*",
      "*#{credential.phone_number}*"
    ]
  end
end
