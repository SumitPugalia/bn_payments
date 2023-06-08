defmodule BnApisWeb.V2.PostController do
  use BnApisWeb, :controller

  alias BnApis.Posts
  alias BnApis.Accounts
  alias BnApis.Helpers.Connection
  alias BnApis.Posts.ContactedPosts

  action_fallback BnApisWeb.FallbackController

  # @post_per_page 10

  @doc """
  Given a post_uuid,
  Gives all post matches (Rent -> Client <-> Property) and vice-versa.
  Returns matches with different brokers(limited to @match_per_broker for a broker)
  """
  def post_matches(
        conn,
        params = %{
          "post_uuid" => post_uuid,
          "post_type" => post_type,
          "post_sub_type" => post_sub_type
          # "page" => page,
        }
      ) do
    logged_in_user = Connection.get_logged_in_user(conn)
    page = (params["page"] && params["page"] |> String.to_integer()) || 1

    method_name = String.to_atom("fetch_#{post_type}_#{post_sub_type}_post_matches_v2")

    with {:ok, {post_in_context, matches, total_matches_count, has_more_matches}} <-
           apply(Posts, method_name, [logged_in_user, post_uuid, page]) do
      conn
      |> put_status(:ok)
      |> json(%{
        matches: matches || [],
        has_more_matches: has_more_matches,
        total_matches_count: total_matches_count,
        post_in_context: post_in_context
      })
    end
  end

  def mark_contacted_and_fetch_counts(conn, %{
        "post_uuid" => post_uuid,
        "post_type" => post_type
      }) do
    logged_in_user = Connection.get_logged_in_user(conn)
    user_id = logged_in_user.user_id
    broker = Accounts.get_broker_by_user_id(user_id)
    post_type = post_type |> String.downcase()
    method_name = String.to_atom("mark_#{post_type}_property_owner_post_contacted")
    {response, to_be_restricted} = ContactedPosts.get_contacted_info_by_user_id(broker.id, post_uuid, post_type)

    is_successfully_contacted = not to_be_restricted
    apply(Posts, method_name, [user_id, post_uuid, post_type, is_successfully_contacted])

    conn
    |> put_status(:ok)
    |> json(response)
  end
end
