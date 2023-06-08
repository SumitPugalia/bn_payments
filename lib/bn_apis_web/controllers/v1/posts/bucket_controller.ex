defmodule BnApisWeb.V1.Posts.BucketController do
  use BnApisWeb, :controller
  alias BnApis.Helpers.Connection
  alias BnApis.Posts.Buckets.Buckets
  alias BnApis.Helpers.Utils
  alias BnApis.Organizations.Broker
  action_fallback BnApisWeb.FallbackController

  def create(conn, params) do
    logged_in_user = Connection.get_logged_in_user(conn)
    broker_id = logged_in_user.broker_id

    with {:ok, bucket} <- Buckets.create(params, broker_id),
         broker <- Broker.fetch_broker_from_id(broker_id),
         bucket <- Buckets.add_matching_properties_count_for_bucket(bucket, broker) do
      conn
      |> put_status(:ok)
      |> put_view(BnApisWeb.V1.Posts.BucketView)
      |> render("bucket.json", %{bucket: bucket})
    end
  end

  def index(conn, params) do
    page_no = Utils.parse_to_integer(params["p"], 1)
    logged_in_user = Connection.get_logged_in_user(conn)
    broker_id = logged_in_user.broker_id

    conn
    |> put_status(:ok)
    |> put_view(BnApisWeb.V1.Posts.BucketView)
    |> render("list.json", Buckets.list(broker_id, page_no))
  end

  def bucket_details(conn, %{"bucket_id" => bucket_id} = params) do
    page_no = Utils.parse_to_integer(params["p"], 1)
    logged_in_user = Connection.get_logged_in_user(conn)
    broker_id = logged_in_user.broker_id

    with {:ok, {posts, total_count, has_more_posts}} <- Buckets.get_bucket_details(broker_id, bucket_id, page_no, logged_in_user[:is_match_plus_active]) do
      conn
      |> put_status(:ok)
      |> json(%{
        posts: posts,
        total_count: total_count,
        has_more_posts: has_more_posts
      })
    end
  end

  def update(conn, %{"bucket_id" => bucket_id} = params) do
    logged_in_user = Connection.get_logged_in_user(conn)
    broker_id = logged_in_user.broker_id
    msg = if Map.get(params, "archive"), do: "Successfully deleted", else: "Successfully updated"

    with :ok <- Buckets.update_bucket(broker_id, bucket_id, params) do
      conn
      |> put_status(:ok)
      |> json(%{message: msg})
    end
  end
end
