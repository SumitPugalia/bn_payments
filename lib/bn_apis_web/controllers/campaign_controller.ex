defmodule BnApisWeb.CampaignController do
  use BnApisWeb, :controller

  require Logger

  alias BnApis.Campaign.CampaignManager
  alias BnApis.Helpers.Connection
  alias BnApis.Campaign.PrimoPass

  action_fallback(BnApisWeb.FallbackController)

  def update_campaign_stats(conn, %{"action" => action, "campaign_id" => campaign_id}) do
    logged_in_user = Connection.get_logged_in_user(conn)
    campaign_id = if is_bitstring(campaign_id), do: String.to_integer(campaign_id), else: campaign_id

    case CampaignManager.update_campaign_stats(campaign_id, logged_in_user.broker_id, String.to_atom(action)) do
      nil ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{message: "Invalid action."})

      {1, _} ->
        conn
        |> put_status(:ok)
        |> json(%{message: "Successfully updated."})

      {0, _} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{message: "Invalid campaign for broker or action already taken."})
    end
  end

  def update_campaign_stats(_conn, _params) do
    {:error, "Invalid params"}
  end

  def active_campaign(conn, _params) do
    logged_in_user = Connection.get_logged_in_user(conn)

    data =
      case CampaignManager.active_campaign_for_broker(logged_in_user.broker_id) do
        nil ->
          %{}

        campaign ->
          %{
            type: "WEB_ALERT",
            data:
              Map.merge(campaign.data, %{
                request_uuid: "#{campaign.id}",
                is_pending_campaign: true
              })
          }
      end

    conn
    |> put_status(:ok)
    |> json(data)
  end

  def create_pass(conn, %{"payload" => pass_payload}) do
    logged_in_user = Connection.get_logged_in_user(conn)

    case PrimoPass.create_pass(logged_in_user.broker_id, pass_payload) do
      {:ok, pass_id} ->
        conn
        |> put_status(:ok)
        |> json(%{pass_id: pass_id})

      {:error, %Ecto.Changeset{}} = error ->
        error

      {:error, reason} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{message: reason})
    end
  end

  def verify_pass_otp(conn, %{"pass_id" => id, "payload" => payload}) do
    case PrimoPass.verify_otp(id, payload) do
      :ok ->
        conn
        |> put_status(:ok)
        |> json(%{})

      {:error, reason} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{message: reason})
    end
  end
end
