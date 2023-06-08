defmodule BnApisWeb.V1.ReminderController do
  use BnApisWeb, :controller

  alias BnApis.Helpers.Connection
  alias BnApis.Reminder
  alias BnApis.Accounts.EmployeeRole

  action_fallback(BnApisWeb.FallbackController)

  plug :access_check,
       [
         allowed_roles: [
           EmployeeRole.member().id,
           EmployeeRole.hl_agent().id,
           EmployeeRole.hl_super().id,
           EmployeeRole.dsa_agent().id,
           EmployeeRole.dsa_admin().id,
           EmployeeRole.dsa_super().id,
           EmployeeRole.super().id
         ]
       ]
       when action in [:create_hl_reminder, :update_hl_reminder]

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

  def get_hl_reminders_for_entity_id(conn, params) do
    entity_type = "homeloan_leads"

    with {:ok, data} <- Reminder.get_reminders_for_entity_id(params, entity_type) do
      conn
      |> put_status(:ok)
      |> json(%{data: data})
    end
  end

  def create_hl_reminder(conn, params) do
    entity_type = "homeloan_leads"
    logged_in_user = Connection.get_employee_logged_in_user(conn)

    with {:ok, _data} <- Reminder.create_reminder(params, logged_in_user.user_id, entity_type) do
      conn
      |> put_status(:ok)
      |> json(%{message: "Created Successfully"})
    end
  end

  def update_broker_reminder(conn, params) do
    with {:ok, _data} <- Reminder.update_reminder(params, conn.assigns[:user]["user_id"]) do
      conn
      |> put_status(:ok)
      |> json(%{message: "Updated Successfully"})
    end
  end

  def update_hl_reminder(conn, params) do
    with {:ok, _data} <- Reminder.update_reminder(params, conn.assigns[:user]["user_id"]) do
      conn
      |> put_status(:ok)
      |> json(%{message: "Updated Successfully"})
    end
  end

  def complete_reminder(conn, params) do
    with {:ok, _data} <- Reminder.complete_reminder(params, conn.assigns[:user]["user_id"]) do
      conn
      |> put_status(:ok)
      |> json(%{message: "Updated Successfully"})
    end
  end

  def cancel_reminder(conn, params) do
    with {:ok, _data} <- Reminder.cancel_reminder(params, conn.assigns[:user]["user_id"]) do
      conn
      |> put_status(:ok)
      |> json(%{message: "Updated Successfully"})
    end
  end

  def get_broker_reminders_for_employee(conn, params) do
    entity_type = "brokers"
    logged_in_user = Connection.get_employee_logged_in_user(conn)

    with {:ok, data} <- Reminder.get_broker_reminders_for_employee(logged_in_user.user_id, entity_type, params) do
      conn
      |> put_status(:ok)
      |> json(%{data: data})
    end
  end

  def create_broker_reminder(conn, params) do
    entity_type = "brokers"
    logged_in_user = Connection.get_employee_logged_in_user(conn)

    with {:ok, _data} <- Reminder.create_reminder(params, logged_in_user.user_id, entity_type) do
      conn
      |> put_status(:ok)
      |> json(%{message: "Created Successfully"})
    end
  end
end
