defmodule BnApisWeb.Admin.BookingRewardsController do
  use BnApisWeb, :controller
  alias BnApis.BookingRewards.BookingRewards
  alias BnApis.BookingRewards.Status
  alias BnApis.Helpers.Connection
  alias BnApis.BookingRewards
  alias BnApis.Accounts.EmployeeRole
  alias BnApis.Helpers.Utils

  action_fallback(BnApisWeb.FallbackController)

  plug(
    :access_check,
    [
      allowed_roles: [
        EmployeeRole.super().id,
        EmployeeRole.admin().id,
        EmployeeRole.invoicing_admin().id,
        EmployeeRole.invoicing_operator().id
      ]
    ]
    when action not in [:fetch_booking_form_for_uuid]
  )

  @valid_status Status.names()
  @changes_requested "changes_requested"
  @approved_by_bn "approved"

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

  def generate_booking_reward_pdf(conn, %{"uuid" => uuid}) do
    user_map = conn |> Connection.get_employee_logged_in_user() |> Utils.get_user_map()

    case BookingRewards.generate_booking_reward_pdf(uuid, user_map) do
      {:ok, url} ->
        conn
        |> put_status(:ok)
        |> json(%{booking_rewards_pdf: url})

      {:error, _reason} = error ->
        error
    end
  end

  def fetch_booking_form_for_uuid(conn, %{"uuid" => uuid}) do
    case BookingRewards.get_booking_map_from_uuid(uuid) do
      {:ok, data} ->
        conn
        |> put_status(:ok)
        |> json(%{results: [data]})

      {:error, _reason} = error ->
        error
    end
  end

  def fetch_booking_form(conn, params = %{"status" => status}) do
    status = String.trim(status) |> String.downcase()
    phone_number = Map.get(params, "phone_number", nil)
    project_name = Map.get(params, "project_name", nil)
    developer_name = Map.get(params, "developer_name", nil)

    with :ok <- valid_status(status, ["all", "approved", "rejected"]),
         {:ok, page, limit} <- parse_page_limit(params) do
      data_list = BookingRewards.fetch_booking_reward_by_status(status, page, limit, phone_number, project_name, developer_name)

      next_page = if length(data_list) == limit, do: page + 1, else: -1

      conn
      |> put_status(:ok)
      |> json(%{results: data_list, next_page: next_page})
    end
  end

  def update_booking_form(conn, params = %{"status" => @changes_requested, "message" => _message, "uuid" => _uuid}) do
    user_map = conn |> Connection.get_employee_logged_in_user() |> Utils.get_user_map()

    case BookingRewards.update_booking_form(params, user_map) do
      nil -> {:error, "invalid uuid"}
      {:ok, _} -> send_resp(conn, 200, "")
      {:error, _reason} = error -> error
    end
  end

  def update_booking_form(conn, %{"status" => @approved_by_bn, "uuid" => uuid}) do
    user_map = conn |> Connection.get_employee_logged_in_user() |> Utils.get_user_map()

    case BookingRewards.mark_as_approved_by_bn(uuid, user_map) do
      {:ok, _} -> send_resp(conn, 200, "Approved Successfully!")
      nil -> {:error, "Invalid booking reward lead"}
      error -> error
    end
  end

  def update_booking_form(
        conn,
        params = %{"uuid" => _uuid, "invoice_number" => _invoice_number, "invoice_date" => _invoice_date}
      ) do
    user_map = conn |> Connection.get_employee_logged_in_user() |> Utils.get_user_map()
    params = Map.take(params, ~w(uuid invoice_number invoice_date))

    case BookingRewards.update_booking_form(params, user_map) do
      nil -> {:error, "invalid uuid"}
      {:ok, _} -> send_resp(conn, 200, "")
      {:error, _reason} = error -> error
    end
  end

  def update_booking_form(conn, %{"uuid" => uuid, "status" => "rejected_by_bn" = status}) do
    user_map = conn |> Connection.get_employee_logged_in_user() |> Utils.get_user_map()

    case BookingRewards.update_booking_form(%{"uuid" => uuid, "status" => status}, user_map) do
      nil -> {:error, "invalid uuid"}
      {:ok, _} -> send_resp(conn, 200, "")
      {:error, _reason} = error -> error
    end
  end

  def update_booking_form(_conn, _), do: {:error, "invalid params"}

  defp parse_page_limit(params) do
    page = Map.get(params, "page", "1") |> String.to_integer()
    limit = Map.get(params, "limit", "30") |> String.to_integer()

    if page < 1 or limit > 100 do
      {:error, "invalid page or limit is too large"}
    else
      {:ok, page, limit}
    end
  end

  defp valid_status(status, extra_read_status),
    do: if(status in (@valid_status ++ extra_read_status), do: :ok, else: {:error, "Invalid status"})
end
