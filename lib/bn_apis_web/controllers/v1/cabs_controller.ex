defmodule BnApisWeb.V1.CabsController do
  use BnApisWeb, :controller

  alias BnApis.Cabs
  alias BnApis.Helpers.{Connection}
  alias BnApis.Accounts.EmployeeRole

  action_fallback(BnApisWeb.FallbackController)

  plug :access_check,
       [
         allowed_roles: [
           EmployeeRole.super().id,
           EmployeeRole.cab_admin().id,
           EmployeeRole.cab_operations_team().id,
           EmployeeRole.cab_operator().id
         ]
       ]
       when action in [
              :assign_chauffeur,
              :cancel_request,
              :complete_request,
              :update_vehicle_in_booking_request,
              :create_operator,
              :update_operator,
              :create_vehicle,
              :update_vehicle,
              :create_driver,
              :update_driver,
              :send_messages_for_booked_cabs,
              :update_whatsapp_sent,
              :get_cab_vehicle_data
            ]

  plug :access_check,
       [allowed_roles: [EmployeeRole.super().id, EmployeeRole.cab_admin().id]]
       when action in [:create_booking_slot, :update_booking_slot, :send_message]

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

  # Apis for broker app
  def create_booking_request(conn, params) do
    with {:ok, data} <- Cabs.create_booking_request(params, conn.assigns[:user]) do
      conn
      |> put_status(:ok)
      |> json(data)
    end
  end

  def create_reroute_booking(conn, params) do
    with {:ok, data} <- Cabs.create_reroute_booking(params, conn.assigns[:user]) do
      conn
      |> put_status(:ok)
      |> json(data)
    end
  end

  def update_booking_request(conn, params) do
    with {:ok, data} <- Cabs.update_booking_request(params, conn.assigns[:user]) do
      conn
      |> put_status(:ok)
      |> json(data)
    end
  end

  def delete_booking_request(conn, params) do
    with {:ok, data} <- Cabs.delete_booking_request(params, conn.assigns[:user]) do
      conn
      |> put_status(:ok)
      |> json(data)
    end
  end

  def get_all_booking_requests_for_broker(conn, params) do
    with {:ok, data} <- Cabs.get_all_booking_requests_for_broker(params, conn.assigns[:user]) do
      conn
      |> put_status(:ok)
      |> json(data)
    end
  end

  # Apis for employee
  def get_all_booking_requests(conn, params) do
    params = Map.put(params, "assigned_broker_ids", fetch_assigned_broker_ids(conn))

    with {:ok, data} <- Cabs.get_all_booking_requests(params, conn.assigns[:user]) do
      conn
      |> put_status(:ok)
      |> json(data)
    end
  end

  def assign_chauffeur(conn, params) do
    params = Map.put(params, "assigned_broker_ids", fetch_assigned_broker_ids(conn))

    with {:ok, data} <- Cabs.assign_vehicle_in_booking_request(params, conn.assigns[:user]) do
      conn
      |> put_status(:ok)
      |> json(data)
    end
  end

  def cancel_request(conn, params) do
    params = Map.put(params, "assigned_broker_ids", fetch_assigned_broker_ids(conn))

    with {:ok, data} <- Cabs.cancel_request(params, conn.assigns[:user]) do
      conn
      |> put_status(:ok)
      |> json(data)
    end
  end

  def complete_request(conn, params) do
    params = Map.put(params, "assigned_broker_ids", fetch_assigned_broker_ids(conn))

    with {:ok, data} <- Cabs.mark_completed(params, conn.assigns[:user]) do
      conn
      |> put_status(:ok)
      |> json(data)
    end
  end

  def update_vehicle_in_booking_request(conn, params) do
    params = Map.put(params, "assigned_broker_ids", fetch_assigned_broker_ids(conn))

    with {:ok, data} <- Cabs.update_vehicle_in_booking_request(params, conn.assigns[:user]) do
      conn
      |> put_status(:ok)
      |> json(data)
    end
  end

  def update_whatsapp_sent(conn, params) do
    with {:ok, data} <- Cabs.update_whatsapp_sent(params, conn.assigns[:user]) do
      conn
      |> put_status(:ok)
      |> json(data)
    end
  end

  def list_operators(conn, params) do
    with {:ok, data} <- Cabs.list_cab_operators(params, conn.assigns[:user]) do
      conn
      |> put_status(:ok)
      |> json(data)
    end
  end

  def create_operator(conn, params) do
    with {:ok, data} <- Cabs.create_operator(params, conn.assigns[:user]) do
      conn
      |> put_status(:ok)
      |> json(data)
    end
  end

  def update_operator(conn, params) do
    with {:ok, data} <- Cabs.update_operator(params, conn.assigns[:user]) do
      conn
      |> put_status(:ok)
      |> json(data)
    end
  end

  def get_cab_vehicle_data(conn, params) do
    with {:ok, data} <- Cabs.get_cab_vehicle_data(params, conn.assigns[:user]) do
      conn
      |> put_status(:ok)
      |> json(data)
    end
  end

  def list_vehicles(conn, params) do
    with {:ok, data} <- Cabs.list_cab_vehicles(params, conn.assigns[:user]) do
      conn
      |> put_status(:ok)
      |> json(data)
    end
  end

  def create_vehicle(conn, params) do
    with {:ok, data} <- Cabs.create_vehicle(params, conn.assigns[:user]) do
      conn
      |> put_status(:ok)
      |> json(data)
    end
  end

  def update_vehicle(conn, params) do
    with {:ok, data} <- Cabs.update_vehicle(params, conn.assigns[:user]) do
      conn
      |> put_status(:ok)
      |> json(data)
    end
  end

  def list_drivers(conn, params) do
    with {:ok, data} <- Cabs.list_cab_drivers(params, conn.assigns[:user]) do
      conn
      |> put_status(:ok)
      |> json(data)
    end
  end

  def create_driver(conn, params) do
    with {:ok, data} <- Cabs.create_driver(params, conn.assigns[:user]) do
      conn
      |> put_status(:ok)
      |> json(data)
    end
  end

  def update_driver(conn, params) do
    with {:ok, data} <- Cabs.update_driver(params, conn.assigns[:user]) do
      conn
      |> put_status(:ok)
      |> json(data)
    end
  end

  def meta(conn, _params) do
    with {:ok, data} <- Cabs.meta() do
      conn
      |> put_status(:ok)
      |> json(data)
    end
  end

  def get_logs_for_booking_request(conn, params) do
    with {:ok, data} <- Cabs.get_logs_for_booking_request(params, conn.assigns[:user]) do
      conn
      |> put_status(:ok)
      |> json(data)
    end
  end

  def create_booking_slot(conn, params) do
    with {:ok, data} <- Cabs.create_booking_slot(params, conn.assigns[:user]) do
      conn
      |> put_status(:ok)
      |> json(data)
    end
  end

  def update_booking_slot(conn, params) do
    with {:ok, data} <- Cabs.update_booking_slot(params, conn.assigns[:user]) do
      conn
      |> put_status(:ok)
      |> json(data)
    end
  end

  def list_booking_slots(conn, params) do
    with {:ok, data} <- Cabs.list_booking_slots(params["city_id"]) do
      conn
      |> put_status(:ok)
      |> json(data)
    end
  end

  def get_booking_slot(conn, params) do
    with {:ok, data} <- Cabs.get_booking_slot(params) do
      conn
      |> put_status(:ok)
      |> json(data)
    end
  end

  def send_messages_for_booked_cabs(conn, params) do
    with {:ok, data} <- Cabs.send_messages_for_booked_cabs(params) do
      conn
      |> put_status(:ok)
      |> json(data)
    end
  end

  def send_message(conn, params) do
    with {:ok, data} <- Cabs.send_message(params) do
      conn
      |> put_status(:ok)
      |> json(data)
    end
  end

  defp fetch_assigned_broker_ids(conn) do
    user = conn.assigns[:user]
    admin_role_ids = [EmployeeRole.super().id, EmployeeRole.cab_admin().id]
    employee_role_id = user["profile"]["employee_role_id"]

    if Enum.member?(admin_role_ids, employee_role_id) do
      nil
    else
      BnApis.AssignedBrokers.fetch_all_active_assigned_brokers(user["user_id"])
    end
  end
end
