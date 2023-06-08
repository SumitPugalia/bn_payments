defmodule BnApisWeb.V1.SubscriptionsController do
  use BnApisWeb, :controller

  alias BnApis.Subscriptions

  action_fallback(BnApisWeb.FallbackController)

  # Apis for broker app
  def get_subscriptions_history(conn, _params) do
    data = Subscriptions.fetch_subscriptions_history(conn.assigns[:user])

    conn
    |> put_status(:ok)
    |> json(%{history: data})
  end

  def create_subscription(conn, _params) do
    with {:ok, data} <- Subscriptions.create_subscription(conn.assigns[:user]) do
      conn
      |> put_status(:ok)
      |> json(data)
    end
  end

  def update_subscription(conn, params) do
    with {:ok, data} <- Subscriptions.update_subscription(params, conn.assigns[:user]) do
      conn
      |> put_status(:ok)
      |> json(data)
    end
  end

  def cancel_subscription(conn, params) do
    with {:ok, data} <- Subscriptions.cancel_subscription(params, conn.assigns[:user]) do
      conn
      |> put_status(:ok)
      |> json(data)
    end
  end

  def mark_subscription_as_registered(conn, params) do
    with {:ok, data} <- Subscriptions.mark_subscription_as_registered(params, conn.assigns[:user]) do
      conn
      |> put_status(:ok)
      |> json(data)
    end
  end
end
