defmodule BnApis.Commercials.CommercialBucket do
  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query

  alias BnApis.Repo
  alias BnApis.Commercials.CommercialPropertyPost
  alias BnApis.Organizations.Broker
  alias BnApis.Accounts.Credential
  alias BnApis.Commercials.CommercialsEnum
  alias BnApis.Commercials.CommercialBucket
  alias BnApis.Commercials.CommercialBucketLog
  alias BnApis.Helpers.Time
  alias BnApis.Accounts.Credential
  alias BnApis.Helpers.ApplicationHelper

  schema "commercial_bucket" do
    field :uuid, Ecto.UUID, read_after_writes: true
    field :token_id, Ecto.UUID, read_after_writes: true
    field :name, :string
    field :option_posts, {:array, :map}, default: []
    field :shortlisted_posts, {:array, :map}, default: []
    field :negotiation_posts, {:array, :map}, default: []
    field :finalized_posts, {:array, :map}, default: []
    field :visit_posts, {:array, :map}, default: []
    field :active, :boolean, default: true

    belongs_to(:broker, Broker)
    timestamps()
  end

  @bucket_options "OPTIONS"
  @bucket_shortlisted "SHORTLISTED"
  @bucket_visits "VISITS"
  @bucket_finalized "FINALIZED"
  @bucket_negotiation "NEGOTIATION"

  @required [:name, :broker_id, :active, :option_posts, :shortlisted_posts, :negotiation_posts, :finalized_posts, :visit_posts]

  def changeset(commercial_site_visit, attrs) do
    commercial_site_visit
    |> cast(attrs, @required)
    |> validate_required(@required)
    |> foreign_key_constraint(:broker_id)
  end

  def create(bucket_name, broker_id) do
    ch =
      CommercialBucket.changeset(%CommercialBucket{}, %{
        name: bucket_name,
        broker_id: broker_id
      })

    if ch.valid? do
      bucket = Repo.insert!(ch)
      {:ok, bucket.id}
    else
      {:error, ch}
    end
  end

  def update(bucket, params) do
    ch = bucket |> CommercialBucket.changeset(params)

    if ch.valid? do
      Repo.update(ch)
      {:ok, "updated successfully"}
    else
      {:error, ch}
    end
  end

  def list_bucket(params, broker_id) do
    {query, content_query, page_no, size} = filter_query(params, broker_id)

    buckets =
      content_query
      |> Repo.all()
      |> Enum.map(fn b ->
        %{
          "uuid" => b.uuid,
          "name" => b.name,
          "id" => b.id,
          "created_at" => Time.naive_to_epoch_in_sec(b.inserted_at),
          "no_of_listing" => length(calculate_uniq_properties(b))
        }
      end)

    total_count = query |> distinct(:id) |> Repo.aggregate(:count, :id)
    next_page_exists = page_no < Float.ceil(total_count / size)

    response = %{
      "buckets" => buckets,
      "has_more" => next_page_exists,
      "total_count" => total_count,
      "next_page_query_params" => "p=#{page_no + 1}"
    }

    {:ok, response}
  end

  defp calculate_uniq_properties(bucket) do
    option_posts_uuids = bucket.option_posts |> Enum.map(& &1["post_uuid"])
    shortlisted_posts_uuids = bucket.shortlisted_posts |> Enum.map(& &1["post_uuid"])
    negotiation_posts_uuids = bucket.negotiation_posts |> Enum.map(& &1["post_uuid"])
    finalized_posts_uuids = bucket.finalized_posts |> Enum.map(& &1["post_uuid"])
    visit_posts_uuids = bucket.visit_posts |> Enum.map(& &1["post_uuid"])
    total_uuids = option_posts_uuids ++ shortlisted_posts_uuids ++ negotiation_posts_uuids ++ finalized_posts_uuids ++ visit_posts_uuids
    total_uuids |> Enum.uniq() |> CommercialPropertyPost.get_valid_uuids()
  end

  def list_bucket_status_post(id, status_id, p, page_size, broker_id, user_id) do
    bucket = CommercialBucket |> Repo.get_by(id: id, broker_id: broker_id)
    status = CommercialsEnum.get_bucket_status_identifier_from_id(status_id)

    case bucket do
      nil ->
        {:error, "Not found"}

      bucket ->
        post_uuids =
          case status do
            @bucket_options -> bucket.option_posts |> Enum.map(& &1["post_uuid"])
            @bucket_shortlisted -> bucket.shortlisted_posts |> Enum.map(& &1["post_uuid"])
            @bucket_finalized -> bucket.finalized_posts |> Enum.map(& &1["post_uuid"])
            @bucket_negotiation -> bucket.negotiation_posts |> Enum.map(& &1["post_uuid"])
            @bucket_visits -> bucket.visit_posts |> Enum.map(& &1["post_uuid"])
            _ -> []
          end

        active_post_uuids = CommercialPropertyPost.get_valid_uuids(post_uuids)

        paginated_post_uuids =
          active_post_uuids
          |> Enum.drop(page_size * (p - 1))
          |> Enum.take(page_size)

        commercial_posts =
          paginated_post_uuids
          |> Enum.map(fn r ->
            {:ok, post} = CommercialPropertyPost.get_post(r, user_id, nil, "V1")
            post
          end)

        response = %{
          "preview_link" => "#{ApplicationHelper.bn_web_base_url()}/commercial/#{bucket.uuid}?token=#{bucket.token_id}",
          "commercial_posts" => commercial_posts,
          "has_more" => p < Float.ceil(Enum.count(active_post_uuids) / page_size),
          "total_count" => Enum.count(active_post_uuids),
          "next_page_query_params" => "p=#{p + 1}"
        }

        {:ok, response}
    end
  end

  def filter_query(params, broker_id) do
    page_no = (params["p"] || "1") |> String.to_integer()
    size = (params["size"] || "20") |> String.to_integer()

    query =
      CommercialBucket
      |> where([b], b.broker_id == ^broker_id and b.active == ^true)

    content_query =
      query
      |> order_by([b], desc: b.inserted_at)
      |> limit(^size)
      |> offset(^((page_no - 1) * size))

    {query, content_query, page_no, size}
  end

  def get_bucket(bucket_id, broker_id, expend_every_post \\ false) do
    bucket = CommercialBucket |> Repo.get_by(id: bucket_id, broker_id: broker_id, active: true)
    logs = CommercialBucketLog.get_log(bucket_id)
    credential = Credential |> Repo.get_by(broker_id: broker_id, active: true)

    case bucket do
      nil ->
        {:error, "Not found"}

      bucket ->
        {:ok,
         %{
           "uuid" => bucket.uuid,
           "id" => bucket.id,
           "name" => bucket.name,
           "created_at" => Time.naive_to_epoch_in_sec(bucket.inserted_at),
           "finalized_posts" => bucket_status_details(bucket.finalized_posts, @bucket_finalized, expend_every_post, credential.id),
           "negotiation_posts" => bucket_status_details(bucket.negotiation_posts, @bucket_negotiation, expend_every_post, credential.id),
           "option_posts" => bucket_status_details(bucket.option_posts, @bucket_options, expend_every_post, credential.id),
           "shortlisted_posts" => bucket_status_details(bucket.shortlisted_posts, @bucket_shortlisted, expend_every_post, credential.id),
           "visit_posts" => bucket_status_details(bucket.visit_posts, @bucket_visits, expend_every_post, credential.id),
           "no_of_listing" => length(calculate_uniq_properties(bucket)),
           "logs" => logs,
           "total_logs" => length(logs),
           "preview_link" => "#{ApplicationHelper.bn_web_base_url()}/commercial/#{bucket.uuid}?token=#{bucket.token_id}"
         }}
    end
  end

  def bucket_status_details(post_list, status_identifier, expend_every_post, user_id) do
    %{
      "posts" => post_list,
      "identifier" => status_identifier,
      "count" => length(post_list),
      "detailed_post" => if(expend_every_post, do: get_every_post_details(post_list, user_id), else: nil)
    }
  end

  def post_count_in_buckets(post_uuid, broker_id) do
    CommercialBucket
    |> where([b], b.broker_id == ^broker_id and b.active == ^true)
    |> select([b], %{
      option_posts: b.option_posts,
      shortlisted_posts: b.shortlisted_posts,
      negotiation_posts: b.negotiation_posts,
      finalized_posts: b.finalized_posts,
      visit_posts: b.visit_posts
    })
    |> Repo.all()
    |> Enum.map(&calculate_uniq_properties(&1))
    |> Enum.count(&Enum.member?(&1, post_uuid))
  end

  defp get_every_post_details(post_list, user_id) do
    post_list
    |> Enum.map(& &1["post_uuid"])
    |> CommercialPropertyPost.get_valid_uuids()
    |> Enum.map(fn r ->
      {:ok, post} = CommercialPropertyPost.get_post(r, user_id, nil, "V1")
      post
    end)
  end

  def send_bucket_view_notif(bucket) do
    credential = Credential.get_credential_from_broker_id(bucket.broker_id)

    if not is_nil(credential) do
      title = "Your client opened the shared bucket"
      message = "#{bucket.name} was viewed "
      type = "NEW_COMMERCIAL_LISTINGS"
      data = %{"title" => title, "message" => message, "bucket_id" => bucket.id}

      Exq.enqueue(Exq, "send_notification", BnApis.Notifications.PushNotificationWorker, [
        credential.fcm_id,
        %{data: data, type: type},
        credential.id,
        credential.notification_platform
      ])
    end
  end

  def get_bucket_options(), do: @bucket_options
  def get_bucket_visits(), do: @bucket_visits
  def get_bucket_shortlisted(), do: @bucket_shortlisted
  def get_bucket_finalized(), do: @bucket_finalized
  def get_bucket_negotiation(), do: @bucket_negotiation
end
