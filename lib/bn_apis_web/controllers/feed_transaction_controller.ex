defmodule BnApisWeb.FeedTransactionController do
  use BnApisWeb, :controller

  alias BnApis.FeedTransactions

  alias BnApis.Accounts.EmployeeRole
  alias BnApis.Helpers.Connection

  alias BnApis.FeedTransactions.FeedTransactionLocality

  action_fallback BnApisWeb.FallbackController

  plug :access_check,
       [allowed_roles: [EmployeeRole.admin().id, EmployeeRole.super().id]] when action in [:admin_update_feed_locality]

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

  def index(conn, params) do
    {feed_transactions, total_count, has_more_feed_transactions} = FeedTransactions.filter_transactions(params)

    render(conn, "index.json",
      feed_transactions: feed_transactions,
      total_count: total_count,
      has_more_feed_transactions: has_more_feed_transactions
    )
  end

  def create(conn, %{"feed_transactions" => feed_transactions}) do
    with {inserted_count, nil} <- FeedTransactions.create_transactions(feed_transactions) do
      send_resp(conn, :ok, "Successfully created #{inserted_count} entries!")
    end
  end

  def create_or_update(conn, %{"feed_transactions" => feed_transactions}) do
    with {count} <- FeedTransactions.create_or_update_transactions(feed_transactions) do
      send_resp(conn, :ok, "Successfully updated #{count} entries!")
    end
  end

  def entities_search(conn, params) do
    entities = FeedTransactions.search_entities(params)
    render(conn, "entities.json", entities: entities)
  end

  def admin_search_feed_localities(conn, _params) do
    feed_localities = FeedTransactionLocality.all_localities()
    render(conn, "feed_localities.json", feed_localities: feed_localities)
  end

  def admin_fetch_feed_locality(conn, %{"feed_locality_id" => feed_locality_id}) do
    feed_locality = FeedTransactionLocality.fetch_by_feed_locality_id(feed_locality_id)

    if is_nil(feed_locality) do
      conn |> put_status(:not_found) |> json(%{message: "Unable to find feed_locality_id #{feed_locality_id}!"})
    else
      render(conn, "feed_locality.json", feed_locality: feed_locality)
    end
  end

  def admin_update_feed_locality(conn, params) do
    feed_locality = FeedTransactionLocality.fetch_by_feed_locality_id(params["feed_locality_id"])

    payload = %{
      "polygon_uuids" => params["polygon_uuids"],
      "city_id" => params["city_id"]
    }

    with {_status, result} <- FeedTransactionLocality.update(feed_locality, payload) do
      render(conn, "feed_locality.json", feed_locality: result)
    end
  end
end
