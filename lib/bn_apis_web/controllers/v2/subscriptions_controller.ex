defmodule BnApisWeb.V2.SubscriptionsController do
  use BnApisWeb, :controller

  alias BnApis.Memberships

  action_fallback(BnApisWeb.FallbackController)

  def create_membership(conn, params) do
    with {:ok, data} <- Memberships.create_membership(params, conn.assigns[:user]) do
      conn
      |> put_status(:ok)
      |> json(data)
    end
  end

  def mark_membership_as_registered(conn, params) do
    with {:ok, data} <- Memberships.mark_membership_as_registered(params, conn.assigns[:user]) do
      conn
      |> put_status(:ok)
      |> json(data)
    end
  end

  def update_membership(conn, params) do
    with {:ok, data} <- Memberships.update_membership(params, conn.assigns[:user]) do
      conn
      |> put_status(:ok)
      |> json(data)
    end
  end

  def cancel_membership(conn, params) do
    with {:ok, data} <- Memberships.cancel_membership(params, conn.assigns[:user]) do
      conn
      |> put_status(:ok)
      |> json(data)
    end
  end

  def fetch_membership_details(conn, params) do
    with {:ok, data} <- Memberships.fetch_membership_details(params, conn.assigns[:user]) do
      conn
      |> put_status(:ok)
      |> json(data)
    end
  end

  def fetch_paytm_subscription_details(conn, params) do
    with {:ok, data} <- Memberships.fetch_paytm_subscription_details(params, conn.assigns[:user]) do
      conn
      |> put_status(:ok)
      |> json(data)
    end
  end

  def fetch_transaction_history(conn, params) do
    with {:ok, data} <- Memberships.fetch_transaction_history(params, conn.assigns[:user]) do
      conn
      |> put_status(:ok)
      |> json(data)
    end
  end

  def update_gst(conn, params) do
    with {:ok, data} <- Memberships.update_gst(params, conn.assigns[:user]) do
      conn
      |> put_status(:ok)
      |> json(data)
    end
  end
end
