defmodule BnApis.Helpers.Connection do
  import Plug.Conn
  alias BnApis.Accounts.ProfileType
  @auth_scheme "Bearer"

  def bearer_auth?(conn) do
    conn
    |> get_authorization_header
    |> String.starts_with?(@auth_scheme <> " ")
  end

  def bearer_auth_creds(conn) do
    conn
    |> get_authorization_header
    |> String.slice((String.length(@auth_scheme) + 1)..-1)
  end

  defp get_authorization_header(conn) do
    auth_header =
      conn
      |> get_req_header("authorization")
      |> List.first()

    auth_header || ""
  end

  def get_logged_in_user(conn) do
    %{
      user_id: conn.assigns[:user]["user_id"],
      uuid: conn.assigns[:user]["uuid"],
      user_type: ProfileType.broker().name,
      phone_number: conn.assigns[:user]["profile"]["phone_number"],
      country_code: conn.assigns[:user]["profile"]["country_code"],
      broker_id: conn.assigns[:user]["profile"]["broker_id"],
      organization_id: conn.assigns[:user]["profile"]["organization_id"],
      organization_name: conn.assigns[:user]["profile"]["organization_name"],
      firm_address: conn.assigns[:user]["profile"]["firm_address"],
      broker_role_id: conn.assigns[:user]["profile"]["broker_role_id"],
      profile_pic_url: conn.assigns[:user]["profile"]["profile_pic_url"],
      name: conn.assigns[:user]["profile"]["name"],
      test_user: conn.assigns[:user]["profile"]["test_user"],
      operating_city: conn.assigns[:user]["profile"]["operating_city"],
      polygon_uuid: conn.assigns[:user]["profile"]["locality"]["polygon_uuid"],
      match_plus_data: conn.assigns[:user]["profile"]["match_plus"],
      is_match_plus_active:
        not is_nil(conn.assigns[:user]["profile"]["match_plus"]) and
          conn.assigns[:user]["profile"]["match_plus"]["is_match_plus_active"]
    }
  end

  def get_employee_logged_in_user(conn) do
    %{
      user_id: conn.assigns[:user]["user_id"],
      uuid: conn.assigns[:user]["uuid"],
      user_type: ProfileType.employee().name,
      phone_number: conn.assigns[:user]["profile"]["phone_number"],
      organization_name: conn.assigns[:user]["profile"]["organization_name"],
      employee_role_id: conn.assigns[:user]["profile"]["employee_role_id"],
      reporting_manager_id: conn.assigns[:user]["profile"]["reporting_manager_id"],
      access_city_ids: conn.assigns[:user]["profile"]["access_city_ids"],
      city_id: conn.assigns[:user]["profile"]["city_id"],
      profile_pic_url: conn.assigns[:user]["profile"]["profile_pic_url"],
      name: conn.assigns[:user]["profile"]["name"],
      skip_allowed: conn.assigns[:user]["profile"]["skip_allowed"],
      vertical_id: conn.assigns[:user]["profile"]["vertical_id"]
    }
  end

  def get_developer_logged_in_user(conn) do
    %{
      user_id: conn.assigns[:user]["user_id"],
      uuid: conn.assigns[:user]["uuid"],
      user_type: ProfileType.developer().name,
      phone_number: conn.assigns[:user]["profile"]["phone_number"],
      profile_pic_url: conn.assigns[:user]["profile"]["profile_pic_url"],
      name: conn.assigns[:user]["profile"]["name"],
      projects: conn.assigns[:user]["profile"]["projects"]
    }
  end

  def get_legal_entity_poc_logged_in_user(conn) do
    %{
      user_id: conn.assigns[:user]["user_id"],
      uuid: conn.assigns[:user]["uuid"],
      phone_number: conn.assigns[:user]["profile"]["phone_number"],
      name: conn.assigns[:user]["profile"]["name"],
      profile_type_id: conn.assigns[:user]["profile"]["profile_type_id"],
      role_type: conn.assigns[:user]["profile"]["role_type"]
    }
  end
end
