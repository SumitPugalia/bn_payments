defmodule BnApisWeb.SubscriptionsController do
  use BnApisWeb, :controller

  alias BnApis.Subscriptions
  alias BnApis.Subscriptions.MatchPlusSubscription
  alias BnApis.Helpers.Connection
  alias BnApis.Accounts.EmployeeRole

  action_fallback(BnApisWeb.FallbackController)

  plug :access_check,
       [allowed_roles: [EmployeeRole.super().id, EmployeeRole.owner_supply_admin().id]]
       when action in [:fetch_subscriptions]

  defp access_check(conn, options) do
    logged_in_user = Connection.get_employee_logged_in_user(conn)

    if logged_in_user.employee_role_id in options[:allowed_roles] do
      conn
    else
      conn
      |> send_resp(401, "Sorry, You are not authorized to take this action!")
      |> halt()
    end
  end

  def fetch_subscriptions(conn, params) do
    with {posts, total_count, has_more_subscriptions} <- MatchPlusSubscription.fetch_subscriptions(params) do
      conn
      |> put_status(:ok)
      |> json(%{
        posts: posts,
        total_count: total_count,
        has_more_subscriptions: has_more_subscriptions
      })
    end
  end

  def send_owner_listings_notifications(conn, %{
        "title" => title,
        "body" => message,
        "phone_numbers" => phone_numbers
      }) do
    phone_numbers = if is_list(phone_numbers), do: phone_numbers, else: []
    Subscriptions.send_owner_listings_notifications(title, message, phone_numbers)

    conn
    |> put_status(:ok)
    |> json(%{"message" => "Successfully enqueued notifications"})
  end
end
