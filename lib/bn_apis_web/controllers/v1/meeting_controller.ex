defmodule BnApisWeb.V1.MeetingController do
  use BnApisWeb, :controller
  alias BnApis.Meetings

  action_fallback(BnApisWeb.FallbackController)

  def create_meeting(conn, params) do
    latitude = Map.get(params, "latitude")
    longitude = Map.get(params, "longitude")
    notes = Map.get(params, "notes")
    broker_id = Map.get(params, "broker_id")

    employee_id = conn.assigns[:user]["user_id"]

    with {:ok, _data} <- Meetings.create_meeting(latitude, longitude, notes, broker_id, employee_id) do
      conn
      |> put_status(:ok)
      |> json(%{"message" => "Meeting created successfully"})
    end
  end

  def get_meetings(conn, params) do
    filter_date = params["filter_date"]
    filter_date = if is_binary(filter_date), do: String.to_integer(filter_date), else: filter_date
    page_no = (params["p"] || "1") |> String.to_integer()
    limit = (params["limit"] || "10") |> String.to_integer()
    employee_id = conn.assigns[:user]["user_id"]

    with {:ok, data} <- Meetings.get_meetings(page_no, employee_id, filter_date, limit) do
      conn
      |> put_status(:ok)
      |> json(data)
    end
  end

  def update_meeting(conn, params) do
    employee_id = conn.assigns[:user]["user_id"]
    meeting_id = params["id"]
    meeting = Meetings.get_meeting_by_id(meeting_id)

    if employee_id != meeting.employee_credentials_id do
      send_resp(conn, 401, "Sorry, You are not authorized to take this action!")
      |> halt()
    end

    with {:ok, _data} <- Meetings.update_meeting(params, meeting) do
      conn
      |> put_status(:ok)
      |> json(%{"message" => "Updated Successfully"})
    end
  end

  def save_lat_long_and_generate_qr(conn, params) do
    latitude = params["latitude"]
    longitude = params["longitude"]
    broker_uuid = conn.assigns[:user]["uuid"]

    with {:ok, data} <- Meetings.save_lat_long_and_generate_qr(latitude, longitude, broker_uuid) do
      conn
      |> put_status(:ok)
      |> json(data)
    end
  end

  def verify_qr_code(conn, params) do
    latitude = params["latitude"]
    longitude = params["longitude"]
    broker_uuid = params["broker_uuid"]
    secret_key = params["secret_key"]

    with {:ok, data} <- Meetings.verify_qr_code(latitude, longitude, broker_uuid, secret_key) do
      conn
      |> put_status(:ok)
      |> json(data)
    end
  end
end
