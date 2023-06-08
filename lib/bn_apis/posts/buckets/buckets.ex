defmodule BnApis.Posts.Buckets.Buckets do
  alias BnApis.Posts.Buckets.Schema.Bucket
  alias BnApis.Repo
  import Ecto.Query
  alias BnApis.Posts.PostType
  alias BnApis.Posts.ConfigurationType
  alias BnApis.Posts.RentalPropertyPost
  alias BnApis.Posts.ResalePropertyPost
  alias BnApis.Helpers.ApplicationHelper
  alias BnApis.Organizations.Broker
  alias BnApis.Posts

  @google_maps_helper ApplicationHelper.get_google_maps_helper_module()
  @month 30 * 24 * 60 * 60
  @limit 30

  def create(params, broker_id) do
    with {:ok, bucket_params} <- create_bucket_params(params, broker_id),
         %Ecto.Changeset{} = changeset <- Bucket.changeset(%Bucket{}, bucket_params),
         {:ok, bucket} <- Repo.insert(changeset) do
      {:ok, bucket}
    else
      {:error, _} = error -> error
    end
  end

  def list_all_after_offset(broker_id, offset \\ @limit) do
    Bucket
    |> where([b], b.broker_id == ^broker_id and b.archived == false)
    |> offset(^offset)
    |> order_by([b], desc: b.inserted_at)
    |> Repo.all()
  end

  def list(broker_id, page_no) do
    offset = (page_no - 1) * @limit

    results =
      Bucket
      |> where([b], b.broker_id == ^broker_id and b.archived == false)
      |> offset(^offset)
      |> limit(^(@limit + 1))
      |> order_by([b], desc: b.inserted_at)
      |> Repo.all()

    buckets = results |> Enum.slice(0, @limit) |> add_matching_properties_count(broker_id)

    %{
      buckets: buckets,
      has_more_buckets: length(results) > @limit,
      badge_count:
        Enum.count(buckets, &(&1.new_number_of_matching_properties > 0)) +
          Enum.count(broker_id |> list_all_after_offset() |> add_matching_properties_count(broker_id), &(&1.new_number_of_matching_properties > 0))
    }
  end

  def add_matching_properties_count_for_bucket(bucket, broker) do
    if is_nil(bucket.last_seen_at) do
      {:ok, number_of_matching_properties} = fetch_posts_count(broker, bucket.filters)
      bucket |> Map.put(:number_of_matching_properties, number_of_matching_properties) |> Map.put(:new_number_of_matching_properties, number_of_matching_properties)
    else
      start_dt = bucket.last_seen_at
      end_dt = DateTime.utc_now() |> DateTime.add(3600, :second) |> DateTime.to_unix()
      {:ok, new_number_of_matching_properties} = fetch_posts_count(broker, bucket.filters, %{"start_date" => start_dt, "end_date" => end_dt})
      old_number_of_matching_properties = bucket.number_of_matching_properties

      bucket
      |> Map.put(:new_number_of_matching_properties, new_number_of_matching_properties)
      |> Map.put(:number_of_matching_properties, new_number_of_matching_properties + old_number_of_matching_properties)
    end
  end

  def get(broker_id, bucket_id) do
    case Repo.one(from b in Bucket, where: b.id == ^bucket_id and b.broker_id == ^broker_id and b.archived == ^false) do
      nil -> {:error, :bucket_not_found}
      bucket -> {:ok, bucket}
    end
  end

  def get_bucket_details(broker_id, bucket_id, page_no, is_match_plus_active) do
    with {:ok, bucket} <- get(broker_id, bucket_id),
         broker <- Broker.fetch_broker_from_id(broker_id),
         {:ok, {posts, total_count, has_more_posts}} <- fetch_posts(broker, bucket.filters, page_no),
         changeset <- Bucket.update_changeset(bucket, %{last_seen_at: DateTime.utc_now() |> DateTime.to_unix(), number_of_matching_properties: total_count}),
         {:ok, _} <- Repo.update(changeset) do
      posts =
        if is_match_plus_active,
          do: posts,
          else: Posts.mask_owner_info_in_posts(posts)

      {:ok, {posts, total_count, has_more_posts}}
    end
  end

  def update_bucket(broker_id, bucket_id, params) do
    with {:ok, bucket} <- get(broker_id, bucket_id),
         bucket_params <- update_bucket_params(params),
         changeset <- Bucket.update_changeset(bucket, bucket_params),
         {:ok, _} <- Repo.update(changeset) do
      :ok
    end
  end

  defp add_matching_properties_count(buckets, broker_id) when is_list(buckets) do
    broker = Broker.fetch_broker_from_id(broker_id)
    buckets |> Enum.map(&add_matching_properties_count_for_bucket(&1, broker))
  end

  defp create_posts_params(filters, attrs) do
    locality_ids = if filters.locality_id, do: [filters.locality_id], else: nil
    building_ids = if filters.building_ids && length(filters.building_ids) > 0, do: filters.building_ids, else: nil

    configuration_type_ids =
      Enum.map(filters.configuration_type, fn val ->
        ConfigurationType.get_by_name(val).id
      end)

    Map.merge(
      %{
        "locality_ids" => locality_ids,
        "configuration_type_ids" => configuration_type_ids,
        "latitude" => filters.latitude,
        "longitude" => filters.longitude,
        "building_ids" => building_ids,
        "added_on" => "asc"
      },
      attrs
    )
  end

  defp fetch_posts(broker, filters, page_no) do
    params = create_posts_params(filters, %{"p" => to_string(page_no)})

    cond do
      filters.post_type == PostType.rent().name ->
        {posts, total_count, has_more_posts, _expiry_wise_count} = RentalPropertyPost.fetch_rental_posts(params, broker, true)
        {:ok, {posts, total_count, has_more_posts}}

      filters.post_type == PostType.resale().name ->
        {posts, total_count, has_more_posts, _expiry_wise_count} = ResalePropertyPost.fetch_resale_posts(params, broker, true)
        {:ok, {posts, total_count, has_more_posts}}

      true ->
        {:error, "couldn't fetch posts because of invalid post_type"}
    end
  end

  defp fetch_posts_count(broker, filters, attrs \\ %{}) do
    params = create_posts_params(filters, attrs)

    cond do
      filters.post_type == PostType.rent().name ->
        total_count = RentalPropertyPost.fetch_rental_posts_count(params, broker, true)
        {:ok, total_count}

      filters.post_type == PostType.resale().name ->
        total_count = ResalePropertyPost.fetch_resale_posts_count(params, broker, true)
        {:ok, total_count}

      true ->
        {:error, "couldn't fetch posts because of invalid post_type"}
    end
  end

  defp update_bucket_params(params) do
    if params["archive"] do
      params |> Map.put("archive_at", DateTime.utc_now() |> DateTime.to_unix()) |> Map.put("archived", true)
    else
      params |> Map.put("expires_at", DateTime.utc_now() |> DateTime.add(@month) |> DateTime.to_unix())
    end
  end

  defp create_bucket_params(params, broker_id) do
    filters =
      if params["filters"] do
        Enum.map(params["filters"], fn
          {"post_type", val} when is_integer(val) ->
            {"post_type", get_post_type_by_id(val)}

          {"post_type", val} when is_binary(val) ->
            case Integer.parse(val) do
              {int_value, ""} -> {"post_type", get_post_type_by_id(int_value)}
              _ -> {"post_type", val}
            end

          {"configuration_type", val} when is_list(val) ->
            {"configuration_type",
             Enum.map(val, fn
               ct when is_integer(ct) ->
                 get_configuration_type_by_id(ct)

               ct when is_binary(ct) ->
                 case Integer.parse(ct) do
                   {int_value, ""} -> get_configuration_type_by_id(int_value)
                   _ -> ct
                 end
             end)}

          {"google_place_id", val} ->
            google_session_token = Map.get(params["filters"], "google_session_token", "")

            case @google_maps_helper.fetch_place_details(val, google_session_token) do
              nil ->
                {"error", "failed to convert google_place_id"}

              place_details_response ->
                latitude = place_details_response.latitude |> Float.to_string()
                longitude = place_details_response.longitude |> Float.to_string()
                [{"latitude", latitude}, {"longitude", longitude}]
            end

          {key, val} ->
            {key, val}
        end)
        |> List.flatten()
        |> Enum.into(%{})
      end

    case Map.get(filters, "error") do
      nil -> {:ok, params |> Map.put("broker_id", broker_id) |> Map.put("filters", filters)}
      error_msg -> {:error, error_msg}
    end
  end

  defp get_post_type_by_id(val) do
    case PostType.get_by_id(val) do
      nil -> "invalid_post"
      post_map -> post_map.name
    end
  end

  defp get_configuration_type_by_id(val) do
    case ConfigurationType.get_by_id(val) do
      nil -> "invalid_configuration"
      configuration_map -> configuration_map.name
    end
  end
end
