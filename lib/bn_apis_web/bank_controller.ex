defmodule BnApisWeb.BankController do
  use BnApisWeb, :controller
  alias BnApis.Homeloan.Bank
  alias BnApis.Accounts.EmployeeRole
  alias BnApis.Helpers.Connection

  action_fallback(BnApisWeb.FallbackController)

  plug :access_check,
       [allowed_roles: [EmployeeRole.member().id, EmployeeRole.hl_agent().id, EmployeeRole.dsa_agent().id, EmployeeRole.super().id, EmployeeRole.hl_super().id]]
       when action in [:add_bank, :update_bank]

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

  def get_all_banks(conn, _params) do
    with {:ok, data} <- Bank.get_all_banks() do
      conn
      |> put_status(:ok)
      |> json(%{data: data})
    end
  end

  def add_bank(conn, params) do
    with {:ok, _data} <- Bank.add_bank(params) do
      conn
      |> put_status(:ok)
      |> json(%{message: "Added Successfully"})
    end
  end

  def update_bank(conn, params) do
    with {:ok, _data} <- Bank.update_bank(params) do
      conn
      |> put_status(:ok)
      |> json(%{message: "Updated Successfully"})
    end
  end
end
