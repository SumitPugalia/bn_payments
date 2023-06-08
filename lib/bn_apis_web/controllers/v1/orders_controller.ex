defmodule BnApisWeb.V1.OrdersController do
  use BnApisWeb, :controller

  alias BnApis.Orders
  alias BnApis.Helpers.Connection
  alias BnApis.Accounts.EmployeeRole
  alias BnApis.Orders.MatchPlus

  action_fallback(BnApisWeb.FallbackController)

  plug :access_check,
       [allowed_roles: [EmployeeRole.super().id, EmployeeRole.owner_supply_admin().id, EmployeeRole.broker_admin().id]]
       when action in [:fetch_match_plus]

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

  def fetch_match_plus(conn, params) do
    with {:validate_broker_id, true} <- {:validate_broker_id, maybe_validate_broker_id?(params["broker_id"])},
         {posts, total_count, has_more_match_plus, expiry_wise_count} <- MatchPlus.fetch_orders(params) do
      conn
      |> put_status(:ok)
      |> json(%{
        posts: posts,
        total_count: total_count,
        has_more_match_plus: has_more_match_plus,
        expiry_wise_count: expiry_wise_count
      })
    else
      {:validate_broker_id, false} ->
        {:error, "invalid broker_id"}
    end
  end

  def fetch_broker_match_plus(conn, params) do
    data = Orders.fetch_broker_orders_history(params["broker_id"])

    conn
    |> put_status(:ok)
    |> json(%{data: data})
  end

  # Apis for broker app
  def get_orders_history(conn, _params) do
    broker_id = conn.assigns[:user] |> get_in(["profile", "broker_id"])
    data = Orders.fetch_broker_orders_history(broker_id)

    conn
    |> put_status(:ok)
    |> json(%{data: data})
  end

  def create_order(conn, params) do
    with {:ok, data} <- Orders.create_order(conn.assigns[:user], params) do
      conn
      |> put_status(:ok)
      |> json(data)
    end
  end

  def update_order(conn, params) do
    with {:ok, data} <- Orders.update_order(params, conn.assigns[:user]) do
      conn
      |> put_status(:ok)
      |> json(data)
    end
  end

  def mark_order_as_paid(conn, params) do
    with {:ok, data} <- Orders.mark_order_as_paid(params, conn.assigns[:user]) do
      conn
      |> put_status(:ok)
      |> json(data)
    end
  end

  def update_gst(conn, params) do
    with {:ok, data} <- Orders.update_gst(params, conn.assigns[:user]) do
      conn
      |> put_status(:ok)
      |> json(data)
    end
  end

  defp maybe_validate_broker_id?(nil), do: true
  defp maybe_validate_broker_id?(broker_id) when is_integer(broker_id), do: true

  defp maybe_validate_broker_id?(broker_id) when is_binary(broker_id) do
    case broker_id |> String.trim() |> Integer.parse() do
      {_v, ""} -> true
      _ -> false
    end
  end
end
