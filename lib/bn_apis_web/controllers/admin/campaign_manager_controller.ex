defmodule BnApisWeb.Admin.CampaignManagerController do
  use BnApisWeb, :controller

  alias BnApis.Campaign.CampaignManager
  alias BnApis.Accounts.EmployeeRole
  alias BnApis.Helpers.Connection

  action_fallback BnApisWeb.FallbackController

  plug :access_check, [allowed_roles: [EmployeeRole.super().id, EmployeeRole.admin().id, EmployeeRole.notification_admin().id]] when action in [:create_campaign, :update_campaign]

  def affected_brokers_count(conn, params) do
    conn
    |> put_status(:ok)
    |> json(CampaignManager.affected_brokers_count(params))
  end

  def create_campaign(
        conn,
        params = %{
          "campaign_identifier" => campaign_identifier,
          "start_date" => start_date,
          "end_date" => end_date,
          "campaign_type" => campaign_type,
          "data" =>
            data = %{
              "url" => _url,
              "title" => _title,
              "subtitle" => _subtitle
            }
        }
      ) do
    with {:ok, campaign} <- CampaignManager.insert_campaign(campaign_identifier, start_date, end_date, campaign_type, data, params) do
      conn
      |> put_status(:ok)
      |> json(create_campaign_map(campaign))
    end
  end

  def update_campaign(conn, params = %{"id" => id}) do
    with {:ok, _campaign} <- CampaignManager.update_campaign(id, params) do
      conn
      |> put_status(:ok)
      |> json(%{message: "Campaign successfully updated."})
    end
  end

  def fetch_campaign(conn, _params = %{"id" => id}) do
    campaign = CampaignManager.fetch_campaign(id)

    if is_nil(campaign) do
      conn
      |> put_status(:not_found)
      |> json(%{message: "Campaign not found."})
    else
      conn
      |> put_status(:ok)
      |> json(create_campaign_map(campaign))
    end
  end

  def fetch_all_campaign_with_details(conn, params) do
    conn
    |> put_status(:ok)
    |> json(%{stats: CampaignManager.fetch_all_campaign_with_details(params)})
  end

  ## Private APIs
  defp create_campaign_map(nil), do: nil

  defp create_campaign_map(campaign) do
    %{
      "id" => campaign.id,
      "campaign_identifier" => campaign.campaign_identifier,
      "start_date" => campaign.start_date,
      "end_date" => campaign.end_date,
      "type" => campaign.type,
      "data" => campaign.data,
      "active" => campaign.active
    }
  end

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
end
