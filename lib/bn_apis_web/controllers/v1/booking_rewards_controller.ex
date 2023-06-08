defmodule BnApisWeb.V1.BookingRewardsController do
  use BnApisWeb, :controller

  alias BnApis.BookingRewards
  alias BnApis.BookingRewards.Schema.BookingRewardsLead
  alias BnApis.BookingRewards.Status
  alias BnApis.Helpers.Connection
  alias BnApis.Places.City

  action_fallback(BnApisWeb.FallbackController)

  @paid_status_id Status.get_status_id!("paid")
  # Api for Broker App
  def create_booking_rewards_lead(conn, params) do
    logged_in_user = Connection.get_logged_in_user(conn)

    with true <- is_valid_operating_city?(logged_in_user),
         {:ok, data} <- BookingRewards.create(params, logged_in_user) do
      conn
      |> put_status(:ok)
      |> json(%{"message" => "Booking Rewards Lead created with id: #{data.id}"})
    else
      false -> {:error, "booking requests is not enabled in your region"}
      {:error, _reason} = error -> error
    end
  end

  def update_booking_rewards_lead(conn, params) do
    logged_in_user = Connection.get_logged_in_user(conn)

    case BookingRewards.update(params, logged_in_user) do
      nil ->
        conn |> put_status(:unprocessable_entity) |> json(%{message: "No entry for given uuid"})

      {:ok, _} ->
        conn
        |> put_status(:ok)
        |> json(%{"message" => "Booking Rewards Lead updated successfully"})

      {:error, reason} ->
        {:error, reason}
    end
  end

  def delete_booking_rewards_lead(conn, %{"uuid" => uuid}) do
    logged_in_user = Connection.get_logged_in_user(conn)

    case BookingRewards.delete(uuid, logged_in_user) do
      :ok ->
        conn
        |> put_status(:ok)
        |> json(%{"message" => "Booking Rewards Lead deleted successfully"})

      {:error, reason} ->
        {:error, reason}
    end
  end

  def fetch_booking_rewards_lead(conn, %{"uuid" => uuid}) do
    case BookingRewards.fetch_booking_rewards_lead(uuid) do
      nil ->
        conn |> put_status(:unprocessable_entity) |> json(%{message: "No entry for given uuid"})

      data ->
        render(conn, "show.json", %{booking_rewards_lead: data})
    end
  end

  def get_brokers_booking_rewards_leads(conn, params) do
    logged_in_user = Connection.get_logged_in_user(conn)

    with {:ok, data} <- BookingRewards.get_brokers_booking_rewards_leads(params, logged_in_user) do
      conn
      |> put_status(:ok)
      |> json(data)
    end
  end

  def update_invoice_details(conn, params) do
    logged_in_user = Connection.get_logged_in_user(conn)

    case BookingRewards.update_invoice_details(params, logged_in_user) do
      nil ->
        conn |> put_status(:unprocessable_entity) |> json(%{message: "No entry for given uuid"})

      {:ok, _data} ->
        conn
        |> put_status(:ok)
        |> json(%{"message" => "Invoice details updated successfully"})

      {:error, reason} ->
        {:error, reason}
    end
  end

  def get_prefill_invoice_details(conn, params) do
    case BookingRewards.fetch_booking_rewards_lead(params["uuid"]) do
      %BookingRewardsLead{status_id: @paid_status_id} = data ->
        render(conn, "invoice_details.json", %{booking_rewards_lead: data})

      nil ->
        conn |> put_status(:unprocessable_entity) |> json(%{message: "No entry for given uuid"})

      _ ->
        conn |> put_status(:unprocessable_entity) |> json(%{message: "Not allowed to get prefill invoice details"})
    end
  end

  defp is_valid_operating_city?(%{operating_city: city_id}) do
    case City.get_city_by_id(city_id) do
      %City{feature_flags: flags} -> Map.get(flags, "booking_rewards", false)
      _ -> false
    end
  end

  defp is_valid_operating_city?(_params), do: false
end
