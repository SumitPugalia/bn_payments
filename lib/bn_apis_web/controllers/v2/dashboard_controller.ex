defmodule BnApisWeb.V2.DashboardController do
  use BnApisWeb, :controller

  alias BnApis.Posts
  alias BnApis.Helpers.{Connection}

  action_fallback BnApisWeb.FallbackController

  def matches_home(conn, params) do
    logged_in_user = Connection.get_logged_in_user(conn)
    page = (params["p"] && params["p"] |> String.to_integer()) || 1
    organization_id = logged_in_user[:organization_id]
    user_id = logged_in_user[:user_id]

    user_data = %{
      user_id: conn.assigns[:user]["user_id"],
      organization_id: conn.assigns[:user]["profile"]["organization_id"],
      operating_city: conn.assigns[:user]["profile"]["operating_city"]
    }

    {:ok, posts_with_matches, has_more_posts} = Posts.fetch_all_posts_with_matches_v2(logged_in_user, organization_id, user_id, page)

    conn
    |> put_status(:ok)
    |> render(BnApisWeb.DashboardView, "dashboard.json",
      posts_with_matches: posts_with_matches,
      expiring_posts: [],
      user_data: user_data,
      page: page,
      has_more: has_more_posts,
      auto_expired_unread_posts_count: 0
    )
  end
end
