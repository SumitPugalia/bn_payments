defmodule BnApisWeb.LocalizationController do
  use BnApisWeb, :controller

  require Logger

  action_fallback(BnApisWeb.FallbackController)

  alias BnApis.IpLoc.API, as: IP

  def login_metadata(conn, params) do
    with {:ok, ip_string} <- validate_login_metadata_params(params),
         {:ok, data} <- IP.get_loc_from_ip(IP.new(), ip_string) do
      conn |> put_status(:ok) |> json(%{valid?: true, country_code: data["countryCode"]})
    else
      {:error, :invaild_ip} ->
        {:error, "Invalid IP address"}

      {:error, 200, data} ->
        {:error, data["message"]}

      {:error, _status, data} ->
        Logger.error("Request to external service failed: login_metadata: IP=#{params["ip"]}, error=#{inspect(data)} ")
        # Revert to default case
        conn |> put_status(:ok) |> json(%{valid?: true, country_code: "IN"})
    end
  end

  def terms_of_use(conn, %{"type" => "generic"}) do
    render(conn, "tnc_generic.html")
  end

  def terms_of_use(conn, %{"type" => "booking_rewards"}) do
    render(conn, "booking_rewards.html")
  end

  defp validate_login_metadata_params(params) do
    ip = Map.get(params, "ip", "")
    count = length(String.split(ip, "."))

    if count == 4 do
      {:ok, ip}
    else
      {:error, :invaild_ip}
    end
  end
end
