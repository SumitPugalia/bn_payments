defmodule BnApisWeb.V1.HomeloanController do
  use BnApisWeb, :controller

  alias BnApis.Repo
  alias BnApis.Accounts.EmployeeRole
  alias BnApis.Homeloans
  alias BnApis.Helpers.{Connection, Utils}
  alias BnApis.Homeloan.Document
  alias BnApis.Accounts.ProfileType
  alias BnApis.Homeloan.DocType
  alias BnApis.Homeloan.Lead
  alias BnApis.Homeloan.LoanDisbursement
  alias BnApis.Organizations.Broker
  alias BnApis.Homeloan.LoanFiles
  alias BnApis.HomeloansPanel
  alias BnApis.Homeloan.Coapplicants
  alias BnApis.Accounts

  action_fallback(BnApisWeb.FallbackController)

  plug :access_check,
       [
         allowed_roles: [
           EmployeeRole.super().id,
           EmployeeRole.hl_agent().id,
           EmployeeRole.hl_super().id,
           EmployeeRole.hl_executive().id,
           EmployeeRole.dsa_agent().id,
           EmployeeRole.dsa_admin().id,
           EmployeeRole.dsa_super().id
         ]
       ]
       when action in [:aggregate_leads, :lead_list_by_filter, :leads_by_phone_number, :add_note, :update_doc]

  plug :access_check,
       [
         allowed_roles: [
           EmployeeRole.super().id,
           EmployeeRole.hl_agent().id,
           EmployeeRole.hl_super().id,
           EmployeeRole.dsa_agent().id,
           EmployeeRole.dsa_admin().id,
           EmployeeRole.dsa_super().id
         ]
       ]
       when action in [:update_lead_status]

  plug :access_check,
       [allowed_roles: [EmployeeRole.super().id, EmployeeRole.hl_super().id, EmployeeRole.dsa_agent().id, EmployeeRole.dsa_admin().id, EmployeeRole.dsa_super().id]]
       when action in [:transfer_leads, :update_active_hl_agents]

  plug :access_check,
       [allowed_roles: [EmployeeRole.dsa_super().id, EmployeeRole.dsa_admin().id, EmployeeRole.super().id, EmployeeRole.dsa_agent().id]]
       when action in [:get_all_leads_for_employee_view, :get_all_leads_for_dsa_view, :get_lead_for_panel_view]

  plug :access_check,
       [allowed_roles: [EmployeeRole.dsa_super().id, EmployeeRole.dsa_admin().id, EmployeeRole.super().id]]
       when action in [:re_upload_documents]

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

  # Api for Broker App
  def create_lead(conn, params) do
    with {:ok, data} <- Homeloans.create_lead(params, conn.assigns[:user]) do
      conn
      |> put_status(:ok)
      |> json(data)
    end
  end

  def get_leads(conn, _params) do
    with {:ok, data} <- Homeloans.lead_list(conn.assigns[:user]) do
      conn
      |> put_status(:ok)
      |> json(data)
    end
  end

  def get_lead_data(conn, params = %{"lead_id" => _lead_id}) do
    logged_in_user = Connection.get_logged_in_user(conn)

    with {:ok, data} <- Homeloans.get_lead_data(params, logged_in_user.broker_id, "V1") do
      conn
      |> put_status(:ok)
      |> json(data)
    end
  end

  def update_lead(conn, params) do
    lead_id = params["id"]
    lead_id = if is_binary(lead_id), do: String.to_integer(lead_id), else: lead_id
    lead = Repo.get_by(Lead, id: lead_id)
    logged_in_user = Connection.get_logged_in_user(conn)

    if logged_in_user.broker_id == lead.broker_id do
      with {:ok, _data} <- Homeloans.update_lead(lead, params) do
        conn
        |> put_status(:ok)
        |> json(%{message: "Lead data updated successfully"})
      end
    else
      conn
      |> send_resp(401, "Sorry, You are not authorized to take this action!")
      |> halt()
    end
  end

  def update_lead_by_agent(conn, params) do
    lead_id = params["id"]
    lead_id = if is_binary(lead_id), do: String.to_integer(lead_id), else: lead_id
    lead = Repo.get_by(Lead, id: lead_id)
    logged_in_user = Connection.get_employee_logged_in_user(conn)

    if logged_in_user.user_id == lead.employee_credentials_id or
         logged_in_user.employee_role_id in [EmployeeRole.hl_super().id, EmployeeRole.super().id, EmployeeRole.dsa_super().id, EmployeeRole.dsa_admin().id] do
      with {:ok, _data} <- Homeloans.update_lead(lead, params) do
        conn
        |> put_status(:ok)
        |> json(%{message: "Lead data updated successfully"})
      end
    else
      conn
      |> send_resp(401, "Sorry, You are not authorized to take this action!")
      |> halt()
    end
  end

  def add_coapplicant(conn, params) do
    lead_id = params["id"]
    lead_id = if is_binary(lead_id), do: String.to_integer(lead_id), else: lead_id
    logged_in_user = Connection.get_employee_logged_in_user(conn)
    lead = Repo.get_by(Lead, id: lead_id)
    params = Map.put(params, "homeloan_lead_id", lead_id)

    if logged_in_user.user_id == lead.employee_credentials_id or
         logged_in_user.employee_role_id in [
           EmployeeRole.hl_super().id,
           EmployeeRole.super().id,
           EmployeeRole.dsa_admin().id,
           EmployeeRole.dsa_agent().id,
           EmployeeRole.dsa_super().id
         ] do
      with {:ok, _data} <- Coapplicants.add_coapplicant(params) do
        conn
        |> put_status(:ok)
        |> json(%{message: "Lead data updated successfully"})
      end
    else
      conn
      |> send_resp(401, "Sorry, You are not authorized to take this action!")
      |> halt()
    end
  end

  def update_coapplicant(conn, params) do
    coapplicant_id = params["id"]
    coapplicant_id = if is_binary(coapplicant_id), do: String.to_integer(coapplicant_id), else: coapplicant_id
    logged_in_user = Connection.get_employee_logged_in_user(conn)
    coapplicant = Repo.get_by(Coapplicants, id: coapplicant_id)
    lead_id = coapplicant.homeloan_lead_id
    lead = Repo.get_by(Lead, id: lead_id)

    if logged_in_user.user_id == lead.employee_credentials_id or
         logged_in_user.employee_role_id in [
           EmployeeRole.hl_super().id,
           EmployeeRole.super().id,
           EmployeeRole.dsa_admin().id,
           EmployeeRole.dsa_agent().id,
           EmployeeRole.dsa_super().id
         ] do
      with {:ok, _data} <- Coapplicants.update_coapplicant(coapplicant, params) do
        conn
        |> put_status(:ok)
        |> json(%{message: "Lead data updated successfully"})
      end
    else
      conn
      |> send_resp(401, "Sorry, You are not authorized to take this action!")
      |> halt()
    end
  end

  def get_doc_types(conn, params) do
    employment_type = params["employment_type"]
    employment_type = if is_binary(employment_type), do: String.to_integer(employment_type), else: employment_type

    with {:ok, data} <- DocType.get_doc_types(employment_type) do
      conn
      |> put_status(:ok)
      |> json(data)
    end
  end

  # Api for employee

  def admin_upload_document(conn, params) do
    logged_in_user = Connection.get_employee_logged_in_user(conn)
    user_map = Utils.get_user_map(logged_in_user)
    uploader_type = ProfileType.employee().name

    with {:ok, _data} <- Document.save_doc(params, conn.assigns[:user], uploader_type, user_map) do
      conn
      |> put_status(:ok)
      |> json(%{message: "Saved successfully"})
    end
  end

  def admin_get_documents(conn, params) do
    user_type = ProfileType.employee().name

    with {:ok, data} <- Document.get_documents(params, user_type) do
      conn
      |> put_status(:ok)
      |> json(data)
    end
  end

  def admin_delete_document(conn, params) do
    logged_in_user = Connection.get_employee_logged_in_user(conn)
    user_map = Utils.get_user_map(logged_in_user)
    user_type = ProfileType.employee().name

    with {:ok, _data} <- Document.delete_document(params, user_type, user_map) do
      conn
      |> put_status(:ok)
      |> json(%{message: "Deleted successfully"})
    end
  end

  # API for broker

  def broker_upload_document(conn, params) do
    logged_in_user = Connection.get_employee_logged_in_user(conn)
    user_map = Utils.get_user_map(logged_in_user)
    uploader_type = ProfileType.broker().name

    with {:ok, _data} <- Document.save_doc(params, conn.assigns[:user], uploader_type, user_map) do
      conn
      |> put_status(:ok)
      |> json(%{message: "Saved successfully"})
    end
  end

  def broker_get_documents(conn, params) do
    user_type = ProfileType.broker().name

    with {:ok, data} <- Document.get_documents(params, user_type) do
      conn
      |> put_status(:ok)
      |> json(data)
    end
  end

  def broker_delete_document(conn, params) do
    logged_in_user = Connection.get_employee_logged_in_user(conn)
    user_map = Utils.get_user_map(logged_in_user)
    user_type = ProfileType.broker().name

    with {:ok, _data} <- Document.delete_document(params, user_type, user_map) do
      conn
      |> put_status(:ok)
      |> json(%{message: "Deleted successfully"})
    end
  end

  ## Get consent from SMS
  def mark_consent(conn, params) do
    if !Browser.bot?(conn) do
      with {:ok, _data} <- Homeloans.mark_sms_consent(params) do
        conn |> redirect(external: "https://loanexpert.app/success")
      else
        {:error, _data} ->
          conn |> redirect(external: "https://loanexpert.app/failure")
      end
    else
      conn |> send_resp(401, "Not Authorised") |> halt()
    end
  end

  # Open Api
  def get_countries(conn, _params) do
    with {:ok, data} <- Homeloans.country_list() do
      conn
      |> put_status(:ok)
      |> json(data)
    end
  end

  # Api for Employee
  def aggregate_leads(conn, params) do
    with {:ok, data} <- Homeloans.aggregate_leads(params, conn.assigns[:user]) do
      conn
      |> put_status(:ok)
      |> json(data)
    end
  end

  def lead_list_by_filter(conn, params) do
    with {:ok, data} <- Homeloans.list_leads_by_status(params, conn.assigns[:user]) do
      conn
      |> put_status(:ok)
      |> json(data)
    end
  end

  def update_lead_status(conn, params) do
    with {:ok, _} <- Homeloans.update_status(params, conn.assigns[:user], "V1") do
      conn
      |> put_status(:ok)
      |> json(%{})
    end
  end

  def validate_pan(conn, %{"pan" => pan}) do
    {flag, message} = Accounts.validate_pan(pan)

    conn
    |> put_status(:ok)
    |> json(%{is_valid: flag, name: message.name})
  end

  def update_lead_status_for_dsa(conn, params) do
    logged_in_user = Connection.get_logged_in_user(conn)

    with {:ok, _} <- Homeloans.update_lead_status_for_dsa(params, logged_in_user.broker_id) do
      conn
      |> put_status(:ok)
      |> json(%{message: "updated succesfully"})
    end
  end

  def transfer_leads(conn, params) do
    logged_in_user = Connection.get_employee_logged_in_user(conn)
    user_map = %{user_id: logged_in_user.user_id, user_type: logged_in_user.user_type}

    with {:ok, _} <- Homeloans.transfer_leads(params["employee_to_transfer"], params["lead_ids"], user_map) do
      conn
      |> put_status(:ok)
      |> json(%{})
    end
  end

  def update_active_hl_agents(conn, params) do
    logged_in_user = Connection.get_employee_logged_in_user(conn)
    user_map = Utils.get_user_map(logged_in_user)

    with {:ok, res} <- Homeloans.update_active_hl_agents(params, user_map) do
      conn
      |> put_status(:ok)
      |> json(res)
    end
  end

  def add_note(conn, params) do
    with {:ok, _} <- Homeloans.add_note(params, conn.assigns[:user]) do
      conn
      |> put_status(:ok)
      |> json(%{})
    end
  end

  def leads_by_phone_number(conn, params) do
    with {:ok, data} <- Homeloans.list_leads_by_phone(params, conn.assigns[:user]) do
      conn
      |> put_status(:ok)
      |> json(data)
    end
  end

  def update_doc(conn, params) do
    with {:ok, data} <- Homeloans.update_doc(params, conn.assigns[:user]) do
      conn
      |> put_status(:ok)
      |> json(data)
    end
  end

  def lead_squared_webhook(conn, params) do
    with {:ok, _} <- Homeloans.handle_lead_squared_webhook(params) do
      conn
      |> put_status(:ok)
      |> json(%{})
    end
  end

  def mark_seen(conn, %{"lead_id" => lead_id}) do
    broker_id = conn.assigns[:user] |> get_in(["profile", "broker_id"])

    with {:ok, _data} <- Homeloans.mark_is_last_status_seen(lead_id) do
      conn
      |> put_status(:ok)
      |> json(%{
        message: "Success",
        home_loan_notification_count: Lead.hl_notification_count(broker_id)
      })
    end
  end

  def get_lead_details(conn, params) do
    with {:ok, data} <- HomeloansPanel.get_lead_details(params["id"]) do
      conn
      |> put_status(:ok)
      |> json(%{
        data: data
      })
    end
  end

  def add_homeloan_disbursement_from_panel(conn, params) do
    with {:ok, _data} <- LoanDisbursement.add_hl_disbursement_from_panel(params) do
      conn
      |> put_status(:ok)
      |> json(%{
        message: "Loan Disbursement added successfully"
      })
    end
  end

  def add_homeloan_disbursement_from_app(conn, params) do
    with {:ok, _data} <- LoanDisbursement.add_hl_disbursement_from_app(params) do
      conn
      |> put_status(:ok)
      |> json(%{
        message: "Loan Disbursement added successfully"
      })
    end
  end

  def mark_tnc_read(conn, _params) do
    broker_id = conn.assigns[:user] |> get_in(["profile", "broker_id"])

    with {:ok, _data} <- Broker.mark_hl_tnc_read(broker_id) do
      conn
      |> put_status(:ok)
      |> json(%{
        message: "Success"
      })
    end
  end

  def edit_homeloan_disbursement_from_app(conn, params) do
    logged_in_user = Connection.get_logged_in_user(conn)
    user_map = %{user_id: logged_in_user.user_id, user_type: logged_in_user.user_type}

    with {:ok, _data} <- LoanDisbursement.edit_homeloan_disbursement(params, user_map) do
      conn
      |> put_status(:ok)
      |> json(%{
        message: "Loan Disbursement updated successfully"
      })
    end
  end

  def edit_homeloan_disbursement_from_panel(conn, params) do
    logged_in_user = Connection.get_employee_logged_in_user(conn)
    user_map = %{user_id: logged_in_user.user_id, user_type: logged_in_user.user_type}

    with {:ok, _data} <- LoanDisbursement.edit_homeloan_disbursement(params, user_map) do
      conn
      |> put_status(:ok)
      |> json(%{
        message: "Loan Disbursement updated successfully"
      })
    end
  end

  def delete_homeloan_disbursement_from_app(conn, params) do
    logged_in_user = Connection.get_logged_in_user(conn)
    user_map = %{user_id: logged_in_user.user_id, user_type: logged_in_user.user_type}

    with {:ok, _data} <- LoanDisbursement.delete_homeloan_disbursement(params["id"], user_map) do
      conn
      |> put_status(:ok)
      |> json(%{
        message: "Loan Disbursement deleted successfully"
      })
    end
  end

  def delete_homeloan_disbursement_from_panel(conn, params) do
    logged_in_user = Connection.get_employee_logged_in_user(conn)
    user_map = %{user_id: logged_in_user.user_id, user_type: logged_in_user.user_type}

    with {:ok, _data} <- LoanDisbursement.delete_homeloan_disbursement(params["id"], user_map) do
      conn
      |> put_status(:ok)
      |> json(%{
        message: "Loan Disbursement deleted successfully"
      })
    end
  end

  def get_all_leads_for_employee_view(conn, params) do
    logged_in_user = Connection.get_employee_logged_in_user(conn)
    user_id = if is_nil(params["user_id"]), do: logged_in_user.user_id, else: params["user_id"]

    with data <- HomeloansPanel.get_all_leads_for_employee_view(user_id, params) do
      conn
      |> put_status(:ok)
      |> json(data)
    end
  end

  def get_all_leads_for_dsa_view(conn, params) do
    logged_in_user = Connection.get_employee_logged_in_user(conn)
    user_id = if is_nil(params["user_id"]), do: logged_in_user.user_id, else: params["user_id"]

    with data <- HomeloansPanel.get_all_leads_for_dsa_view(user_id, params) do
      conn
      |> put_status(:ok)
      |> json(data)
    end
  end

  def get_lead_for_panel_view(conn, params) do
    logged_in_user = Connection.get_employee_logged_in_user(conn)
    user_id = if is_nil(params["user_id"]), do: logged_in_user.user_id, else: params["user_id"]
    user_type = Map.get(params, "user_type", "employee")

    with data <- HomeloansPanel.get_lead_for_panel_view(user_id, params, user_type) do
      conn
      |> put_status(:ok)
      |> json(data)
    end
  end

  def create_loan_file_from_panel(conn, params) do
    with {:ok, _data} <- LoanFiles.create_loan_file_from_panel(params, conn.assigns[:user]) do
      conn
      |> put_status(:ok)
      |> json(%{
        message: "Loan file created successfully"
      })
    end
  end

  def update_loan_file_from_panel(conn, params) do
    with {:ok, _data} <- LoanFiles.update_loan_file_from_panel(params, conn.assigns[:user]) do
      conn
      |> put_status(:ok)
      |> json(%{
        message: "Loan file Updated successfully"
      })
    end
  end

  def create_loan_file(conn, params) do
    with {:ok, _data} <- LoanFiles.create_loan_file(params, conn.assigns[:user]) do
      conn
      |> put_status(:ok)
      |> json(%{
        message: "Loan file created successfully"
      })
    end
  end

  def update_loan_file(conn, params) do
    with {:ok, _data} <- LoanFiles.update_loan_file(params, conn.assigns[:user]) do
      conn
      |> put_status(:ok)
      |> json(%{
        message: "Loan file Updated successfully"
      })
    end
  end

  def re_upload_documents(conn, params) do
    with {:ok, _data} <- Homeloans.re_upload_documents(params) do
      conn
      |> put_status(:ok)
      |> json(%{
        message: "Document Uploaded Successfully"
      })
    end
  end

  def delete_lead_from_admin(conn, _params = %{"id" => lead_id}) do
    with {:ok, _data} <- Homeloans.delete_lead_from_admin(lead_id) do
      conn
      |> put_status(:ok)
      |> json(%{
        message: "lead successfully removed"
      })
    end
  end

  def change_commission_on_from_panel(conn, _params = %{"disbursement_id" => disbursement_id, "amount" => amount, "commission_applicable_on" => commission_applicable_on}) do
    logged_in_user = Connection.get_employee_logged_in_user(conn)
    user_map = %{user_id: logged_in_user.user_id, user_type: logged_in_user.user_type}

    with {:ok, _data} <- LoanDisbursement.change_commission_on_from_panel(disbursement_id, amount, commission_applicable_on, user_map) do
      conn
      |> put_status(:ok)
      |> json(%{
        message: "successfully updated"
      })
    end
  end
end
