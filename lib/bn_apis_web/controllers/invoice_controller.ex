defmodule BnApisWeb.InvoiceController do
  use BnApisWeb, :controller

  alias BnApis.Stories.{Invoice, BookingInvoice}
  alias BnApis.Accounts.EmployeeRole
  alias BnApis.Helpers.{Connection, Utils}
  alias BnApis.Organizations.{BillingCompany, BankAccount}
  alias BnApis.Organizations.Broker
  alias BnApis.Homeloan.InvoiceRemarks

  action_fallback BnApisWeb.FallbackController

  plug :access_check,
       [allowed_roles: [EmployeeRole.super().id, EmployeeRole.invoicing_admin().id, EmployeeRole.dsa_admin().id, EmployeeRole.dsa_super().id, EmployeeRole.dsa_finance().id]]
       when action in [
              :update_invoice_by_uuid,
              :mark_as_approved,
              :mark_as_rejected,
              :request_changes,
              :update_invoice_number_and_date,
              :mark_as_paid,
              :admin_generate_invoice_pdf,
              :admin_create_booking_invoice_pdf,
              :admin_generate_signed_tnc_pdf,
              :update_invoice_by_uuid_for_dsa
            ]

  def post_piramal_invoice_to_panel(conn, params) do
    user_map = conn.assigns[:user]
    invoice_params = sanitize_params(params)

    with {:ok, _invoice} <- Invoice.post_piramal_invoice_to_panel(invoice_params, user_map) do
      conn
      |> put_status(:ok)
      |> json(%{message: "Invoice data successfully published to BN Panel."})
    end
  end

  @spec all_invoices(Plug.Conn.t(), map) :: Plug.Conn.t()
  def all_invoices(conn, params) do
    logged_in_user = Connection.get_employee_logged_in_user(conn)
    logged_in_user.employee_role_id

    conn
    |> put_status(:ok)
    |> json(Invoice.all_invoices(params, logged_in_user.employee_role_id, logged_in_user.user_id))
  end

  @spec fetch_invoice_by_uuid(Plug.Conn.t(), map) :: Plug.Conn.t()
  def fetch_invoice_by_uuid(conn, %{"uuid" => uuid}) do
    invoice = Invoice.fetch_invoice_by_uuid(uuid)

    if is_nil(invoice) do
      conn
      |> put_status(:not_found)
      |> json(%{message: "Invoice not found."})
    else
      conn
      |> put_status(:ok)
      |> json(invoice)
    end
  end

  @spec fetch_invoice_by_uuid(Plug.Conn.t(), map) :: Plug.Conn.t()
  def update_invoice_by_uuid_for_dsa(conn, params) do
    logged_in_user = Connection.get_employee_logged_in_user(conn)
    user_map = %{user_id: logged_in_user.user_id, user_type: logged_in_user.user_type}

    with {:ok, _invoice} <- Invoice.update_invoice_by_uuid_for_dsa(params, user_map) do
      conn
      |> put_status(:ok)
      |> json(%{message: "Invoice successfully updated."})
    end
  end

  def fetch_invoice_for_broker_by_uuid(conn, %{"uuid" => uuid}) do
    logged_in_user = Connection.get_logged_in_user(conn)
    broker_id = logged_in_user.broker_id
    invoice = Invoice.fetch_invoice_for_broker_by_uuid(uuid, broker_id)

    if is_nil(invoice) do
      conn
      |> put_status(:not_found)
      |> json(%{message: "Invoice not found."})
    else
      conn
      |> put_status(:ok)
      |> json(invoice)
    end
  end

  @spec fetch_all_invoice_for_broker(Plug.Conn.t(), any) :: Plug.Conn.t()
  def fetch_all_invoice_for_broker(conn, params) do
    logged_in_user = Connection.get_logged_in_user(conn)
    broker_id = logged_in_user.broker_id
    broker_role_id = logged_in_user.broker_role_id
    org_id = logged_in_user.organization_id
    role_type_id = Broker.fetch_broker_from_id(broker_id).role_type_id
    status = Map.get(params, "status", nil)
    page_no = Map.get(params, "p", "1") |> String.to_integer() |> max(1)
    limit = Map.get(params, "limit", "25") |> String.to_integer() |> max(1) |> min(100)
    search_text = Map.get(params, "search_text", nil)
    invoice = Invoice.fetch_all_invoice_for_broker(broker_id, broker_role_id, role_type_id, org_id, status, page_no, limit, search_text)

    if is_nil(invoice) do
      conn
      |> put_status(:not_found)
      |> json(%{message: "Invoice not found."})
    else
      conn
      |> put_status(:ok)
      |> json(invoice)
    end
  end

  @spec create_invoice_for_broker(
          atom
          | %{:assigns => nil | maybe_improper_list | map, optional(any) => any},
          map
        ) :: {:error, any} | Plug.Conn.t()
  def create_invoice_for_broker(conn, params) do
    logged_in_user = Connection.get_logged_in_user(conn)
    broker_id = logged_in_user.broker_id
    user_map = %{user_id: logged_in_user.user_id, user_type: logged_in_user.user_type}
    broker_role_id = logged_in_user.broker_role_id
    org_id = logged_in_user.organization_id
    role_type_id = Broker.fetch_broker_from_id(broker_id).role_type_id
    params = maybe_change_status_to_admin_review_pending(params, broker_role_id, role_type_id)

    with :ok <- valid_params_for_create_invoice(params),
         {:ok, invoice} <- Invoice.create_invoice(params, broker_id, broker_role_id, role_type_id, org_id, user_map) do
      conn
      |> put_status(:ok)
      |> json(invoice)
    end
  end

  def update_invoice_by_uuid(conn, params) do
    logged_in_user = Connection.get_employee_logged_in_user(conn)
    user_map = %{user_id: logged_in_user.user_id, user_type: logged_in_user.user_type}

    with {:ok, _invoice} <- Invoice.update_invoice_by_uuid(params, user_map, logged_in_user.employee_role_id) do
      conn
      |> put_status(:ok)
      |> json(%{message: "Invoice successfully updated."})
    end
  end

  def update_invoice_for_broker(conn, params) do
    logged_in_user = Connection.get_logged_in_user(conn)
    broker_id = logged_in_user.broker_id
    broker_role_id = logged_in_user.broker_role_id
    role_type_id = Broker.fetch_broker_from_id(broker_id).role_type_id
    user_map = %{user_id: logged_in_user.user_id, user_type: logged_in_user.user_type}
    params = maybe_change_status_to_admin_review_pending(params, broker_role_id, role_type_id)

    with {:ok, _invoice} <- Invoice.update_invoice_for_broker(params, broker_id, user_map) do
      conn
      |> put_status(:ok)
      |> json(%{message: "Invoice successfully updated."})
    end
  end

  def generate_invoice_pdf(conn, params = %{"uuid" => _uuid}) do
    logged_in_user = Connection.get_logged_in_user(conn)
    user_map = %{user_id: logged_in_user.user_id, user_type: logged_in_user.user_type}

    with {:ok, invoice_pdf_url} <- Invoice.generate_invoice_pdf(params, user_map) do
      conn
      |> put_status(:ok)
      |> json(%{invoice_pdf_url: invoice_pdf_url})
    end
  end

  def admin_generate_invoice_pdf(conn, params = %{"uuid" => _uuid}) do
    logged_in_user = Connection.get_employee_logged_in_user(conn)
    params = Map.put(params, "employee_role_id", logged_in_user.employee_role_id)
    user_map = %{user_id: logged_in_user.user_id, user_type: logged_in_user.user_type}

    with {:ok, invoice_pdf_url} <- Invoice.generate_invoice_pdf(params, user_map) do
      conn
      |> put_status(:ok)
      |> json(%{invoice_pdf_url: invoice_pdf_url})
    end
  end

  def create_booking_invoice_pdf(conn, %{"invoice_uuid" => invoice_uuid}) do
    logged_in_user = Connection.get_logged_in_user(conn)
    user_map = %{user_id: logged_in_user.user_id, user_type: logged_in_user.user_type}

    with {:ok, booking_invoice_pdf_url} <- BookingInvoice.create_booking_invoice_pdf(invoice_uuid, user_map) do
      conn
      |> put_status(:ok)
      |> json(%{booking_invoice_pdf_url: booking_invoice_pdf_url})
    end
  end

  def admin_create_booking_invoice_pdf(conn, %{"invoice_uuid" => invoice_uuid}) do
    logged_in_user = Connection.get_employee_logged_in_user(conn)
    user_map = %{user_id: logged_in_user.user_id, user_type: logged_in_user.user_type}

    with {:ok, booking_invoice_pdf_url} <- BookingInvoice.create_booking_invoice_pdf(invoice_uuid, user_map) do
      conn
      |> put_status(:ok)
      |> json(%{booking_invoice_pdf_url: booking_invoice_pdf_url})
    end
  end

  def invoices_meta(conn, _params) do
    billing_company_types = BillingCompany.get_billing_company_types()
    places_of_supply = BillingCompany.get_valid_place_of_supply()
    bank_account_types = BankAccount.get_bank_account_types()

    meta_data = %{
      "billing_company_types" => billing_company_types,
      "places_of_supply" => places_of_supply,
      "bank_account_types" => bank_account_types
    }

    conn
    |> put_status(:ok)
    |> json(meta_data)
  end

  def mark_as_approved(conn, %{"uuid" => uuid} = params) do
    logged_in_user = Connection.get_employee_logged_in_user(conn)
    user_map = %{user_id: logged_in_user.user_id, user_type: logged_in_user.user_type}

    with {:ok, _invoice} <- Invoice.mark_as_approved(uuid, params["proof_urls"], user_map, logged_in_user.employee_role_id) do
      conn
      |> put_status(:ok)
      |> json(%{message: "Invoice approved."})
    end
  end

  def mark_as_rejected(conn, params = %{"uuid" => _uuid}) do
    logged_in_user = Connection.get_employee_logged_in_user(conn)
    user_map = %{user_id: logged_in_user.user_id, user_type: logged_in_user.user_type}

    with {:ok, _invoice} <- Invoice.mark_as_rejected(params, user_map, logged_in_user.employee_role_id) do
      conn
      |> put_status(:ok)
      |> json(%{message: "Invoice rejected."})
    end
  end

  def change_status(conn, %{"uuid" => uuid, "status" => status}) do
    logged_in_user = Connection.get_employee_logged_in_user(conn)
    user_map = %{user_id: logged_in_user.user_id, user_type: logged_in_user.user_type}
    employee_role_id = logged_in_user.employee_role_id

    with {:ok, _invoice} <- Invoice.change_status(uuid, user_map, status, employee_role_id) do
      conn
      |> put_status(:ok)
      |> json(%{message: "Invoice status changed."})
    end
  end

  def request_changes(conn, %{"uuid" => uuid, "change_notes" => change_notes}) do
    logged_in_user = Connection.get_employee_logged_in_user(conn)
    user_map = %{user_id: logged_in_user.user_id, user_type: logged_in_user.user_type}

    with {:ok, _invoice} <- Invoice.request_changes(uuid, change_notes, user_map, logged_in_user.employee_role_id) do
      conn
      |> put_status(:ok)
      |> json(%{message: "Invoice status updated to changes requested."})
    end
  end

  def update_invoice_number_and_date(conn, %{
        "uuid" => uuid,
        "invoice_date" => invoice_date,
        "invoice_number" => invoice_number
      }) do
    logged_in_user = Connection.get_employee_logged_in_user(conn)
    user_map = %{user_id: logged_in_user.user_id, user_type: logged_in_user.user_type}

    with {:ok, _invoice} <- Invoice.update_invoice_number_and_date(uuid, invoice_date, invoice_number, user_map, logged_in_user.employee_role_id) do
      conn
      |> put_status(:ok)
      |> json(%{message: "Invoice Number and date successfully updated."})
    end
  end

  def mark_as_paid(conn, %{
        "uuid" => uuid,
        "is_advance_payment" => is_advance_payment,
        "payment_utr" => payment_utr,
        "payment_mode" => payment_mode
      }) do
    logged_in_user = Connection.get_employee_logged_in_user(conn)
    user_map = %{user_id: logged_in_user.user_id, user_type: logged_in_user.user_type}

    with {:ok, _invoice} <- Invoice.mark_as_paid(uuid, is_advance_payment, payment_utr, payment_mode, user_map, logged_in_user.employee_role_id) do
      conn
      |> put_status(:ok)
      |> json(%{message: "Invoice marked as paid."})
    end
  end

  def delete_invoice(conn, %{"uuid" => uuid}) do
    logged_in_user = Connection.get_logged_in_user(conn)
    broker_id = logged_in_user.broker_id
    user_map = Utils.get_user_map(logged_in_user)

    with {:ok, _invoice} <- Invoice.delete_invoice(uuid, broker_id, user_map) do
      conn
      |> put_status(:ok)
      |> json(%{message: "Invoice successfully deleted."})
    end
  end

  def get_invoice_logs(conn, params = %{"invoice_id" => invoice_id}) do
    page_no = Map.get(params, "p", "1") |> Utils.parse_to_integer()

    with {:ok, logs} <- Invoice.get_invoice_logs(invoice_id, page_no) do
      conn
      |> put_status(:ok)
      |> json(logs)
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

  defp sanitize_params(params) do
    Enum.reduce(params, %{}, fn
      {k, v}, params when is_bitstring(v) -> Map.put(params, k, String.trim(v))
      {k, v}, params -> Map.put(params, k, v)
    end)
  end

  def admin_generate_signed_tnc_pdf(conn, params) do
    case Invoice.generate_signed_tnc(params["uuid"], params["aadhar_number"], params["email_id"]) do
      {:ok, pdf_link} -> conn |> put_status(:ok) |> json(%{"pdf" => pdf_link})
      {:error, reason} -> {:error, reason}
    end
  end

  defp valid_params_for_create_invoice(%{
         "story_id" => _,
         "status" => _status,
         "invoice_number" => _invoice_number,
         "invoice_date" => _invoice_date,
         "legal_entity_id" => _legal_entity_id,
         "billing_company_id" => _billing_company_id,
         "invoice_items" => _invoice_items
       }) do
    :ok
  end

  defp valid_params_for_create_invoice(%{
         "loan_disbursements_id" => _,
         "status" => _status,
         "invoice_number" => _invoice_number,
         "invoice_date" => _invoice_date,
         "billing_company_id" => _billing_company_id
       }) do
    :ok
  end

  defp valid_params_for_create_invoice(_params), do: {:error, "Invalid Params"}

  defp maybe_change_status_to_admin_review_pending(params, 2, 1) do
    inv =
      if not is_nil(params["uuid"]) do
        Invoice.fetch_invoice_by_uuid(params["uuid"])
      else
        nil
      end

    if Map.get(params, "status") == "approval_pending" and not is_nil(inv) and inv["status"] not in ["changes_requested", "approval_pending"] do
      Map.put(params, "status", "admin_review_pending")
    else
      params
    end
  end

  defp maybe_change_status_to_admin_review_pending(params, _, _), do: params

  def mark_as_approved_by_org_admin(conn, %{"uuid" => uuid}) do
    logged_in_user = Connection.get_logged_in_user(conn)
    user_map = %{user_id: logged_in_user.user_id, user_type: logged_in_user.user_type}
    broker_id = logged_in_user.broker_id
    broker_role_id = logged_in_user.broker_role_id
    role_type_id = Broker.fetch_broker_from_id(broker_id).role_type_id

    with {:ok, _invoice} <- Invoice.mark_as_approved_by_org_admin(uuid, user_map, broker_role_id, role_type_id) do
      conn
      |> put_status(:ok)
      |> json(%{message: "Invoice approved."})
    end
  end

  def mark_as_rejected_by_org_admin(conn, %{"uuid" => uuid, "change_notes" => rejection_reason}) do
    logged_in_user = Connection.get_logged_in_user(conn)
    user_map = %{user_id: logged_in_user.user_id, user_type: logged_in_user.user_type}
    broker_id = logged_in_user.broker_id
    broker_role_id = logged_in_user.broker_role_id
    role_type_id = Broker.fetch_broker_from_id(broker_id).role_type_id

    with {:ok, _invoice} <- Invoice.mark_as_rejected_by_org_admin(uuid, rejection_reason, user_map, broker_role_id, role_type_id) do
      conn
      |> put_status(:ok)
      |> json(%{message: "Invoice rejected."})
    end
  end

  def add_remark(conn, params = %{"invoice_id" => invoice_id}) do
    logged_in_user = Connection.get_employee_logged_in_user(conn)

    with {:ok, _invoice} <- InvoiceRemarks.add_remark(params["remark"], invoice_id, logged_in_user.user_id) do
      conn
      |> put_status(:ok)
      |> json(%{message: "Invoice remark added."})
    end
  end

  def edit_remark(conn, params = %{"invoice_remark_id" => invoice_remark_id}) do
    logged_in_user = Connection.get_employee_logged_in_user(conn)

    with {:ok, _invoice} <- InvoiceRemarks.edit_remark(params["remark"], invoice_remark_id, logged_in_user.user_id) do
      conn
      |> put_status(:ok)
      |> json(%{message: "Invoice remark edited."})
    end
  end

  def delete_remark(conn, _params = %{"invoice_remark_id" => invoice_remark_id}) do
    with {:ok, _invoice} <- InvoiceRemarks.delete_remark(invoice_remark_id) do
      conn
      |> put_status(:ok)
      |> json(%{message: "Invoice remark deleted."})
    end
  end
end
