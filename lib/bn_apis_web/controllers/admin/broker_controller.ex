defmodule BnApisWeb.Admin.BrokerController do
  use BnApisWeb, :controller

  alias BnApis.Accounts.EmployeeRole
  alias BnApis.Organizations.Broker
  alias BnApis.Helpers.Connection

  action_fallback(BnApisWeb.FallbackController)

  plug(
    :access_check,
    [
      allowed_roles: [
        EmployeeRole.super().id,
        EmployeeRole.admin().id,
        EmployeeRole.broker_admin().id,
        EmployeeRole.kyc_admin().id,
        EmployeeRole.invoicing_admin().id,
        EmployeeRole.invoicing_operator().id
      ]
    ]
    when action in [:mark_kyc_as_approved, :mark_kyc_as_rejected]
  )

  def mark_kyc_as_approved(conn, %{"id" => id}) do
    logged_in_user = Connection.get_employee_logged_in_user(conn)
    user_map = %{user_id: logged_in_user.user_id, user_type: logged_in_user.user_type}

    with {:ok, _broker} <- Broker.mark_kyc_as_approved(id, user_map) do
      conn
      |> put_status(:ok)
      |> json(%{message: "Broker KYC marked as approved."})
    end
  end

  def mark_kyc_as_rejected(conn, %{"id" => id, "change_notes" => change_notes}) do
    logged_in_user = Connection.get_employee_logged_in_user(conn)
    user_map = %{user_id: logged_in_user.user_id, user_type: logged_in_user.user_type}

    with {:ok, _broker} <- Broker.mark_kyc_as_rejected(id, change_notes, user_map) do
      conn
      |> put_status(:ok)
      |> json(%{message: "Broker KYC marked as rejected"})
    end
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
