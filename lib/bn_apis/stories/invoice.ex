defmodule BnApis.Stories.Invoice do
  use Ecto.Schema
  import Ecto.Query

  alias BnApis.Organizations.BrokerRole
  alias BnApis.Accounts.Credential
  alias BnApis.{Repo, Log}
  alias BnApis.Helpers.AuditedRepo
  alias BnApis.Stories.Schema.Invoice
  alias BnApis.Stories.{Story, LegalEntity, InvoiceItem, BookingInvoice, LegalEntityPocMapping}
  alias BnApis.Organizations.{Broker, BillingCompany, Organization, BankAccount}
  alias BnApis.Helpers.Time
  alias BnApis.BookingRewards
  alias BnApis.Helpers.{Utils, InvoiceHelper, ExternalApiHelper, ApplicationHelper, S3Helper}
  alias BnApisWeb.Helpers.PhoneHelper, as: Phone
  alias BnApis.Stories.Story
  alias BnApis.Homeloan.LoanDisbursement
  alias BnApis.Accounts.EmployeeCredential
  alias BnApis.Accounts.EmployeeRole
  alias BnApis.Homeloan.Lead
  alias BnApis.Schemas.LegalEntityPoc
  alias BnApis.Stories.Schema.PocApprovals
  alias BnApis.Stories.LegalEntityPocMapping
  alias BnApis.Homeloan.LeadType
  alias BnApis.Homeloan.Bank
  alias BnApis.Rewards.InvoicePayout
  alias BnApis.Homeloan.InvoiceRemarks

  @approved_by_bn_invoice_status "approved"
  @rejected_by_bn_invoice_status "rejected"
  @changes_requested_invoice_status "changes_requested"
  @paid_invoice_status "paid"

  @approval_pending "approval_pending"
  @deleted_status "deleted"
  @draft_status "draft"
  @admin_review_pending "admin_review_pending"
  @rejected_by_admin "rejected_by_admin"
  @approved_by_finance "approved_by_finance"
  @approved_by_crm "approved_by_crm"
  @rejected_by_finance "rejected_by_finance"
  @rejected_by_crm "rejected_by_crm"
  @invoice_requested "invoice_requested"
  @approved_by_admin "approved_by_admin"
  @approved_by_super "approved_by_super"

  @rejected_status_list [@rejected_by_bn_invoice_status, @rejected_by_finance, @rejected_by_crm]

  @broker_invoice_types [Invoice.type_reward(), Invoice.type_brokerage()]
  @approval_pending_invoice_display_text "Approval Pending"
  @changes_requested_display_text "Changes Requested"
  @invoice_requested_display_text "Invoice Requested"

  @override_after_days -3
  @invoice_type_brokerage "brokerage"
  @invoice_type_booking_reward "booking_reward"
  @invoice_type_dsa "dsa"
  @invoice_pending_status ~w(approval_pending changes_requested approved_by_finance)

  @cgst 0.09
  @sgst 0.09
  @tds 0.01
  @tcs 0.01
  @igst 0.18
  @imgix_domain ApplicationHelper.get_imgix_domain()

  @valid_cities_in_maharastra [1, 2]

  @loan_disbursements :loan_disbursements
  @stories :stories

  @dsa_admin_role_id EmployeeRole.dsa_admin()[:id]
  @dsa_super_role_id EmployeeRole.dsa_super()[:id]
  @dsa_finance_role_id EmployeeRole.dsa_finance()[:id]

  @legal_entity_poc_type_crm LegalEntityPoc.poc_type_crm()
  @legal_entity_poc_type_finance LegalEntityPoc.poc_type_finance()
  @legal_entity_poc_type_admin LegalEntityPoc.poc_type_admin()

  @pending_poc_invoice_flag "pending"
  @approved_poc_invoice_flag "approved"

  def preload_invoice_entity(%Invoice{entity_id: nil, entity_type: nil} = invoice), do: invoice

  def preload_invoice_entity(%Invoice{entity_type: entity_type} = invoice) do
    key = from_entity_type_to_key(entity_type)
    Map.put(invoice, key, get_entity_from_invoice(invoice))
  end

  def preload_invoice_entity(invoice), do: invoice

  def get_entity_from_invoice(%Invoice{} = %{entity_type: @loan_disbursements, entity_id: entity_id}),
    do: Repo.get_by(LoanDisbursement, id: entity_id) |> Repo.preload([:homeloan_lead, loan_file: :bank])

  def get_entity_from_invoice(%Invoice{} = %{entity_type: @stories, entity_id: entity_id}), do: Repo.get_by(Story, id: entity_id)

  @doc """
    Piramal API - Creates an approved invoice based on params provided by piramal
  """
  def post_piramal_invoice_to_panel(
        params = %{
          "broker_name" => broker_name,
          "phone_number" => phone_number,
          "organization_name" => organization_name,
          "organization_gst_number" => organization_gst_number,
          "billing_company_name" => billing_company_name,
          "address" => address,
          "billing_company_place_of_supply" => billing_company_place_of_supply,
          "company_type" => company_type,
          "billing_company_pan" => billing_company_pan,
          "rera_id" => rera_id,
          "bill_to_state" => bill_to_state,
          "bill_to_pincode" => bill_to_pincode,
          "bill_to_city" => bill_to_city,
          "account_holder_name" => account_holder_name,
          "bank_ifsc" => bank_ifsc,
          "bank_account_type" => bank_account_type,
          "account_number" => account_number,
          "confirm_account_number" => confirm_account_number,
          "legal_entity_name" => legal_entity_name,
          "gst" => gst,
          "pan" => pan,
          "place_of_supply" => place_of_supply,
          "brokerage_record_id" => brokerage_record_id,
          "brokerage_amount" => brokerage_amount,
          "agreement_value" => agreement_value,
          "building_name" => building_name,
          "customer_name" => customer_name,
          "unit_number" => unit_number,
          "wing_name" => wing_name
        },
        user_map
      ) do
    signature = Map.get(params, "signature", "")
    email = Map.get(params, "email", "") |> String.trim()
    billing_company_gst = Map.get(params, "billing_company_gst", "")
    bank_name = Map.get(params, "bank_name", "")
    cancelled_cheque = Map.get(params, "cancelled_cheque", "")
    sac = Map.get(params, "sac")
    billing_address = Map.get(params, "billing_address", "")
    state_code = Map.get(params, "state_code")
    shipping_address = Map.get(params, "shipping_address", "")
    ship_to_name = Map.get(params, "ship_to_name", "")

    bank_account_params =
      create_bank_account_params(
        account_holder_name,
        bank_ifsc,
        bank_account_type,
        account_number,
        confirm_account_number,
        bank_name,
        cancelled_cheque
      )

    billing_company_params =
      create_billing_company_params(
        billing_company_name,
        address,
        billing_company_place_of_supply,
        company_type,
        billing_company_pan,
        rera_id,
        bill_to_state,
        bill_to_pincode,
        bill_to_city,
        signature,
        email,
        billing_company_gst,
        bank_account_params
      )

    legal_entity_params =
      create_legal_entity_params(
        legal_entity_name,
        gst,
        pan,
        place_of_supply,
        sac,
        billing_address,
        state_code,
        shipping_address,
        ship_to_name
      )

    invoice_items_params =
      create_invoice_items_params(
        brokerage_amount,
        agreement_value,
        building_name,
        customer_name,
        unit_number,
        wing_name
      )

    Repo.transaction(fn ->
      with {:ok, %{id: organization_id}} <- Organization.find_or_create_organization(organization_name, organization_gst_number),
           {:ok, phone_number, country_code} <- Phone.parse_phone_number(%{"phone_number" => phone_number}),
           {:ok, %{id: broker_id}} <-
             Broker.find_or_create_broker(broker_name, phone_number, country_code, organization_id, user_map),
           {:ok, %{"id" => billing_company_id}} <- BillingCompany.create(billing_company_params, broker_id, BrokerRole.admin().id),
           {:ok, %{"id" => legal_entity_id}} <- LegalEntity.find_or_create_legal_entity(legal_entity_params, user_map),
           {:ok, invoice} <-
             create_invoice_params(
               @approved_by_crm,
               brokerage_record_id,
               legal_entity_id,
               billing_company_id,
               invoice_items_params,
               _is_created_by_piramal = true
             )
             |> create_invoice(broker_id, organization_id, user_map),
           true <- auto_approve_by_bn_bots(invoice, user_map) do
        generate_invoice_pdf(invoice, user_map)
        invoice_uuid = Map.get(invoice, "uuid")
        BookingInvoice.create_booking_invoice_pdf(invoice_uuid, user_map)
        invoice
      else
        false -> {:error, "Auto approve failed"}
        {:error, error} -> Repo.rollback(error)
      end
    end)
  end

  def post_piramal_invoice_to_panel(_params, _user_map),
    do: {:error, "Invalid params for publishing invoice to BN Panel."}

  @doc """
    Lists all the the invoices companies.
  """
  def all_invoices(params, emp_role_id, emp_id) do
    page_no = Map.get(params, "p", "1") |> String.to_integer() |> max(1)
    limit = Map.get(params, "limit", "30") |> String.to_integer() |> max(1) |> min(100)
    status = Map.get(params, "status") |> parse_string()
    project_name = Map.get(params, "project_name") |> parse_string()
    broker_phone_number = Map.get(params, "broker_phone_number") |> parse_string()
    developer_name = Map.get(params, "developer_name") |> parse_string()
    is_enabled_for_commercial = Map.get(params, "is_enabled_for_commercial") |> parse_string()
    broker_name = Map.get(params, "broker_name") |> parse_string()
    billing_company_name = Map.get(params, "company_name") |> parse_string()

    get_paginated_results(
      page_no,
      limit,
      status,
      project_name,
      broker_phone_number,
      developer_name,
      is_enabled_for_commercial || "false",
      broker_name,
      billing_company_name,
      emp_id,
      emp_role_id
    )
  end

  @doc """
    Fetches an invoice based on uuid.
  """
  def fetch_invoice_by_uuid(uuid) do
    invoice = get_invoice_by_uuid(uuid)

    if is_nil(invoice) do
      nil
    else
      invoice_items_map = InvoiceItem.get_active_invoice_items(invoice)
      create_invoice_map(invoice, invoice_items_map)
    end
  end

  @doc """
    Fetches an invoice based on uuid for a broker.
  """
  def fetch_invoice_for_broker_by_uuid(uuid, broker_id) do
    invoice = get_invoice_for_broker_by_uuid(uuid, broker_id)

    if is_nil(invoice) do
      nil
    else
      invoice_items_map = InvoiceItem.get_active_invoice_items(invoice)
      create_invoice_map(invoice, invoice_items_map)
    end
  end

  @doc """
    Fetches invoices for a broker.
  """
  def fetch_all_invoice_for_broker(broker_id, broker_role_id, role_type_id, org_id, status, page_no, limit, search_text) do
    offset = (page_no - 1) * limit
    query = get_invoices_by_broker_id_query(broker_id, broker_role_id, role_type_id, org_id, status, search_text)

    invoices =
      query
      |> preload([
        :broker,
        :legal_entity,
        :billing_company,
        invoice_approvals: [:legal_entity_poc],
        billing_company: [:bank_account],
        booking_rewards_lead: [:invoices]
      ])
      |> order_by(desc: :id)
      |> limit(^limit)
      |> offset(^offset)
      |> Repo.all()

    invoices_map =
      invoices
      |> Enum.map(fn invoice ->
        invoice = preload_invoice_entity(invoice)
        invoice_items_map = InvoiceItem.get_active_invoice_items(invoice)
        create_invoice_map_for_broker(invoice, invoice_items_map, broker_id)
      end)

    %{
      "invoices" => invoices_map,
      "next_page_exists" => Enum.count(invoices) >= limit,
      "next_page_query_params" => "p=#{page_no + 1}",
      "has_admin_privileges" => broker_role_id == BrokerRole.admin().id and role_type_id == Broker.real_estate_broker()["id"]
    }
  end

  @doc """
    Panel - Updates an invoice based on uuid.
  """
  def update_invoice_by_uuid(
        params = %{
          "uuid" => uuid,
          "status" => status,
          "invoice_number" => invoice_number,
          "invoice_date" => invoice_date,
          "broker_id" => broker_id,
          "legal_entity_id" => legal_entity_id,
          "billing_company_id" => billing_company_id
        },
        user_map,
        role_id
      ) do
    status = parse_string(status)
    invoice = get_invoice_by_uuid(uuid)
    entity_map = get_entity_id_and_type(params)
    has_access? = can_user_update_invoice?(invoice, role_id, user_map.user_id)


    cond do
      has_access? == false ->
        {:error, :invalid_access}

      is_nil(invoice) ->
        {:error, "Invoice not found."}

      is_nil(invoice.booking_rewards_lead_id) == false and status == @changes_requested_invoice_status ->
        {:error, "changes_requested is not allowed for invoice created using booking reward flow."}

      invoice.is_created_by_piramal ->
        {:error, "Update not allowed for invoices created by Piramal."}

      invoice ->
        Repo.transaction(fn ->
          invoice
          |> Invoice.changeset(
            Map.merge(entity_map, %{
              status: status,
              invoice_number: invoice_number,
              invoice_date: invoice_date,
              broker_id: broker_id,
              legal_entity_id: parse_legal_entity_id(legal_entity_id, invoice.legal_entity_id),
              billing_company_id: billing_company_id
            })
          )
          |> AuditedRepo.update(user_map)
          |> case do
            {:ok, invoice} ->
              invoice_items_map =
                if params["invoice_items"] do
                  invoice_items_map =
                    Enum.map(params["invoice_items"], fn invoice_item ->
                      case InvoiceItem.update_invoice_item(invoice_item, invoice.id, user_map) do
                        {:ok, invoice_item} ->
                          invoice_item

                        {:error, error} ->
                          Repo.rollback(error)
                      end
                    end)

                  deactivate_invoice_items(invoice, invoice_items_map, user_map)
                else
                  []
                end

              create_invoice_map(invoice, invoice_items_map)

            {:error, error} ->
              Repo.rollback(error)
          end
        end)
    end
  end

  defp maybe_generate_invoice_for_dsa(user_map, invoice) when invoice.type == "dsa" and not is_nil(invoice.loan_disbursements.commission_percentage) do
    generate_dsa_homeloan_invoice(invoice, user_map, %{"loan_commission" => invoice.loan_disbursements.commission_percentage})
  end

  defp maybe_generate_invoice_for_dsa(_, invoice), do: {:ok, invoice}

  def update_invoice_by_uuid(_params, _user_map), do: {:error, "Invalid params."}

  def update_invoice_by_uuid_for_dsa(params, user_map) do
    invoice = get_invoice_by_uuid(params["uuid"])

    invoice
    |> Invoice.changeset(params)
    |> AuditedRepo.update(user_map)
    |> case do
      {:ok, invoice} ->  maybe_generate_invoice_for_dsa(user_map, invoice)

      {:error, error} -> {:error, error}
    end
  end

  @doc """
    App - Updates an invoice based on uuid for a broker.
  """
  def update_invoice_for_broker(
        params = %{
          "uuid" => uuid,
          "status" => status,
          "invoice_number" => invoice_number,
          "invoice_date" => invoice_date,
          "legal_entity_id" => legal_entity_id,
          "billing_company_id" => billing_company_id
        },
        broker_id,
        user_map
      ) do
    status = parse_string(status)
    invoice = get_invoice_for_broker_by_uuid(uuid, broker_id)
    entity_map = get_entity_id_and_type(params)

    cond do
      is_nil(invoice) ->
        {:error, "Invoice not found."}

      invoice.is_created_by_piramal ->
        {:error, "Update not allowed for invoices created by Piramal."}

      status in ([@approved_by_bn_invoice_status, @paid_invoice_status, @approved_by_finance, @approved_by_crm] ++ @rejected_status_list) ->
        {:error, "Updating status to Approved, Paid or Rejected not allowed for a broker."}

      is_nil(invoice.booking_rewards_lead_id) == false and invoice.status == "draft" ->
        invoice
        |> Invoice.changeset(%{status: @approval_pending})
        |> AuditedRepo.update(user_map)

      is_nil(invoice.booking_rewards_lead_id) == false ->
        {:error, "update is not allowed for invoice created using booking reward flow."}

      invoice ->
        Repo.transaction(fn ->
          invoice
          |> Invoice.changeset(
            Map.merge(entity_map, %{
              status: status,
              invoice_number: invoice_number,
              invoice_date: invoice_date,
              legal_entity_id: parse_legal_entity_id(legal_entity_id, invoice.legal_entity_id),
              billing_company_id: billing_company_id
            })
          )
          |> AuditedRepo.update(user_map)
          |> case do
            {:ok, invoice} ->
              if params["invoice_items"] do
                invoice_items_map =
                  Enum.map(params["invoice_items"], fn invoice_item ->
                    case InvoiceItem.update_invoice_item(invoice_item, invoice.id, user_map) do
                      {:ok, invoice_item} ->
                        invoice_item

                      {:error, error} ->
                        Repo.rollback(error)
                    end
                  end)

                deactivate_invoice_items(invoice, invoice_items_map, user_map)
              end

              invoice

            {:error, error} ->
              Repo.rollback(error)
          end
        end)
    end
  end

  def update_invoice_for_broker(_params, _broker_id, _user_map), do: {:error, "Invalid invoice params."}

  @doc """
    Creates an invoice based on provided params.
  """
  def create_invoice(
        params = %{
          "status" => _status,
          "invoice_number" => _invoice_number,
          "invoice_date" => _invoice_date,
          "legal_entity_id" => _legal_entity_id,
          "billing_company_id" => _billing_company_id
        },
        broker_id,
        broker_role_id,
        role_type_id,
        organization_id,
        user_map
      ) do
    Repo.transaction(fn ->
      with {:valid, true} <- {:valid, can_create_invoice?(params, broker_id)},
           {:ok, invoice} <- create_new_invoice(params, broker_id, organization_id, user_map),
           invoice <- preload_invoice(invoice),
           {1, _} <- update_invoice_id_in_loan_disbursement(invoice) do
        Task.async(fn -> maybe_send_notification_to_admins(broker_role_id, role_type_id, organization_id) end)
        create_invoice_map(invoice, InvoiceItem.get_active_invoice_items(invoice))
      else
        {:valid, false} ->
          Repo.rollback("cannot create multiple invoice for same id")

        {0, _} ->
          Repo.rollback("disbursement id doesnt exist")

        {:error, reason} ->
          Repo.rollback(reason)
      end
    end)
  end

  def create_invoice(_params, _broker_id, _organization_id, _user_map), do: {:error, "Invalid invoice params."}

  def generate_invoice_pdf(params, user_map) do
    uuid = Map.get(params, "uuid")

    invoice = get_invoice_by_uuid(uuid)

    cond do
      is_nil(invoice) -> {:error, "Invoice does not exist."}
      invoice.type == Invoice.type_reward() -> BookingRewards.create_booking_reward_invoice_pdf(invoice, user_map)
      invoice.type == Invoice.type_dsa() -> generate_dsa_homeloan_invoice(invoice, user_map, params)
      true -> generate_advance_brokerage_invoice(invoice, user_map)
    end
  end

  def get_invoice_by_uuid(nil), do: nil

  def get_invoice_by_uuid(uuid) do
    Invoice
    |> preload([
      :broker,
      :legal_entity,
      :invoice_items,
      invoice_approvals: [:legal_entity_poc],
      billing_company: [:bank_account],
      booking_rewards_lead: [:invoices]
    ])
    |> Repo.get_by(uuid: uuid)
    |> case do
      nil -> nil
      invoice -> preload_invoice_entity(invoice)
    end
  end

  def mark_as_approved(uuid, proof_urls, user_map, role_id) do
    with %Invoice{is_created_by_piramal: false} = invoice <- get_invoice_by_uuid(uuid),
         true <- can_user_update_invoice?(invoice, role_id, user_map.user_id),
         {:ok, invoice} <-
           invoice
           |> Invoice.changeset(%{status: @approved_by_bn_invoice_status, proof_urls: proof_urls})
           |> AuditedRepo.update(user_map) do
      broadcast_to_poc_whatsapp(invoice)
      {:ok, invoice}
    else
      nil -> {:error, "Invoice not found."}
      %Invoice{} -> {:error, "Invoice created by Piramal are already pre-approved."}
      false -> {:error, :invalid_access}
      {:error, reason} -> {:error, reason}
    end
  end

  def mark_as_rejected(params, user_map, role_id) do
    uuid = params["uuid"]

    with %Invoice{is_created_by_piramal: false} = invoice <- get_invoice_by_uuid(uuid),
         true <- can_user_update_invoice?(invoice, role_id, user_map.user_id) do
      invoice
      |> Invoice.changeset(%{status: @rejected_by_bn_invoice_status, rejection_reason: params["rejection_reason"]})
      |> AuditedRepo.update(user_map)
    else
      nil -> {:error, "Invoice not found."}
      %Invoice{} -> {:error, "This operation is not allowed for invoices created by Piramal."}
      false -> {:error, :invalid_access}
    end
  end

  def change_status(uuid, user_map, status, employee_role_id) do
    with %Invoice{is_created_by_piramal: false} = invoice <- get_invoice_by_uuid(uuid) do
      changeset_params = if employee_role_id == @dsa_super_role_id, do: %{status: status, approved_by_super_id: user_map.user_id}, else: %{status: status}

      invoice
      |> Invoice.changeset(changeset_params)
      |> AuditedRepo.update(user_map)
    else
      nil -> {:error, "Invoice not found."}
      %Invoice{} -> {:error, "This operation is not allowed for invoices created by Piramal."}
    end
  end

  def request_changes(uuid, change_notes, user_map, role_id) do
    with %Invoice{is_created_by_piramal: false} = invoice <- get_invoice_by_uuid(uuid),
         true <- can_user_update_invoice?(invoice, role_id, user_map.user_id),
         {:ok, invoice} <- Invoice.changeset(invoice, %{status: @changes_requested_invoice_status, change_notes: change_notes}) |> AuditedRepo.update(user_map) do
      send_changes_requested_fcm_notification(invoice, change_notes)
      {:ok, invoice}
    else
      {:error, _reason} = error -> error
      nil -> {:error, "Invoice not found."}
      %Invoice{} -> {:error, "This operation is not allowed for invoices created by Piramal."}
      false -> {:error, :invalid_access}
    end
  end

  def update_invoice_number_and_date(uuid, invoice_date, invoice_number, user_map, role_id) do
    invoice_date = Utils.parse_to_integer(invoice_date)
    with %Invoice{is_created_by_piramal: false} = invoice <- get_invoice_by_uuid(uuid),
         true <- can_user_update_invoice?(invoice, role_id, user_map.user_id) do
      invoice
      |> Invoice.changeset(%{invoice_date: invoice_date, invoice_number: invoice_number})
      |> AuditedRepo.update(user_map)
      |> case do
        {:ok, updated_invoice} ->
          if(not is_nil(invoice.invoice_pdf_url) and invoice.type == "dsa") do
            generate_dsa_homeloan_invoice(updated_invoice, user_map, %{"loan_commission" => invoice.loan_disbursements.commission_percentage})
          end
          {:ok, updated_invoice}
        {:error, err} -> {:error, err}
      end
    else
      nil -> {:error, "Invoice not found."}
      %Invoice{} -> {:error, "This operation is not allowed for invoices created by Piramal."}
      false -> {:error, :invalid_acccess}
    end
  end

  def mark_as_paid(uuid, is_advance_payment, payment_utr, payment_mode, user_map, role_id) do
    with %Invoice{} = invoice <- get_invoice_by_uuid(uuid),
         true <- can_user_update_invoice?(invoice, role_id, user_map.user_id) do
      Repo.transaction(fn ->
        with {:ok, invoice} <- mark_invoice_as_paid(invoice, is_advance_payment, payment_utr, payment_mode, user_map),
             {:ok, _} <- mark_all_disbursement_as_paid(invoice, invoice.type),
             {:ok, _} <- BookingRewards.maybe_update_status_to_paid(invoice.booking_rewards_lead, user_map, invoice.type),
             {:ok, invoice} <- post_data_to_piramal(invoice.is_created_by_piramal, invoice) do
          invoice
        else
          {:error, changeset} -> Repo.rollback(changeset)
        end
      end)
    else
      nil -> {:error, "Invoice not found."}
      false -> {:error, :invalid_acccess}
    end
  end

  def mark_to_be_paid(uuid_list, employee_role_id, user_map) do
    Enum.reduce(uuid_list, %{}, fn uuid, failure ->
      with %Invoice{} = invoice <- get_invoice_by_uuid(uuid),
           {:true, _}  <- check_for_valid_invoice_amount(invoice.total_payable_amount),
           {:razorpay, {:ok, fund_id}} <- {:razorpay, get_fund_account_id_for_invoice(invoice)},
           {:ok, _} <- InvoicePayout.add_new_pending_payout(invoice, fund_id, user_map),
           {:ok, _} <- change_status(uuid, user_map, "payment_in_progress", employee_role_id) do
        failure
      else
        nil -> Map.put(failure, uuid, :not_found)
        {:false, _} ->
          change_status(uuid, user_map, "paid", employee_role_id)
          failure
        {:razorpay, {:error, error_desc}} ->
          change_status(uuid, user_map, "payment_failed", employee_role_id)
          Map.put(failure, uuid, error_desc)
        {:error, changeset} -> Map.put(failure, uuid, changeset)
      end
    end)
  end

  def check_for_valid_invoice_amount(total_payable_amount) do
    if(is_nil(total_payable_amount) or total_payable_amount <= 0 ) do
      {:false, total_payable_amount}
    else
      {:true, total_payable_amount}
    end
  end

  def get_fund_account_id_for_invoice(invoice) do
    with {:fund_id, nil} <- {:fund_id, invoice.billing_company.razorpay_fund_account_id},
         {:cred, credential} when not is_nil(credential) <- {:cred, Credential.get_credential_from_broker_id(invoice.broker.id)},
         {:razorpay, {:ok, fund_id}} <- {:razorpay, BnApis.Accounts.update_bank_acount_into_razorpay(invoice.billing_company.bank_account, credential)},
         {:ok, changeset} <- BillingCompany.changeset(invoice.billing_company, %{razorpay_fund_account_id: fund_id}),
         {:ok, _} <- Repo.update(changeset) do
      {:ok, fund_id}
    else
      {:fund_id, fund_id} -> {:ok, fund_id}
      {:cred, nil} -> {:error, :not_found}
      {:razorpay, {:error, error_desc}} -> {:error, error_desc}
      error -> error
    end
  end

  defp mark_all_disbursement_as_paid(invoice, type) when type == @invoice_type_dsa do
    loan_disbursement = LoanDisbursement |> Repo.get_by(id: invoice.entity_id) |> Repo.preload(loan_file: :bank)

    case loan_disbursement do
      nil ->
        {:ok, invoice}

      loan_disbursement ->
        if(loan_disbursement.loan_file.bank.commission_on == :sanctioned_amount) do
          LoanDisbursement
          |> where([l], l.homeloan_lead_id == ^loan_disbursement.homeloan_lead_id and l.id != ^invoice.entity_id and l.active == true)
          |> update(set: [invoice_id: ^invoice.id])
          |> Repo.update_all([])

          {:ok, invoice}
        else
          {:ok, invoice}
        end
    end
  end

  defp mark_all_disbursement_as_paid(invoice, _type), do: {:ok, invoice}

  def get_invoice_balance(story_id) do
    invoices =
      Invoice
      |> join(:left, [i], b in assoc(i, :booking_invoice))
      |> where(
        [i],
        i.story_id == ^story_id and not is_nil(i.booking_rewards_lead_id) and i.status in ^(@invoice_pending_status ++ [@paid_invoice_status, @approved_by_crm])
      )
      |> select([i, b], %{type: i.type, booking_invoice: %{invoice_amount: b.invoice_amount}, status: i.status, bonus_amount: i.bonus_amount})
      |> Repo.all()

    Enum.reduce(invoices, %{}, fn invoice, map ->
      cond do
        invoice.status in @invoice_pending_status -> add_invoice_wallet_amount_to_map(invoice, map, "pending")
        invoice.status == @paid_invoice_status -> add_invoice_wallet_amount_to_map(invoice, map, @paid_invoice_status)
        invoice.status == @approved_by_crm -> add_invoice_wallet_amount_to_map(invoice, map, @approved_by_crm)
        true -> map
      end
    end)
  end

  def delete_invoice(uuid, broker_id, user_map) do
    invoice = get_invoice_for_broker_by_uuid(uuid, broker_id)

    cond do
      is_nil(invoice) ->
        {:error, :not_found}

      invoice.is_created_by_piramal ->
        {:error, "This operation is not allowed for invoices created by Piramal."}

      invoice.status == @deleted_status ->
        {:error, "Invoice has already been deleted."}

      invoice.status in [@draft_status, @approval_pending, @changes_requested_invoice_status] ->
        invoice
        |> Invoice.changeset(%{status: @deleted_status})
        |> AuditedRepo.update(user_map)

      true ->
        {:error, "Delete operation not allowed."}
    end
  end

  def update_invoice_status_by_poc(poc_id, invoice_uuid, changes, user_map, action) do
    with %LegalEntityPoc{active: true} = poc <- LegalEntityPoc.get_by_id(poc_id),
         %Invoice{} = invoice <- get_invoice_by_uuid(invoice_uuid) |> preload_invoice_entity(),
         {:poc, true} <- {:poc, can_poc_update_invoice_status?(poc, invoice)} do
      changes = Map.take(changes, ~w(status change_notes)a)
      approved_at = DateTime.to_unix(DateTime.utc_now())

      Repo.transaction(fn ->
        with {:ok, invoice} <- Invoice.changeset(invoice, changes) |> AuditedRepo.update(user_map),
             {:ok, poc_approval} <-
               PocApprovals.new(%{role_type: poc.poc_type, action: action, legal_entity_poc_id: poc_id, invoice_id: invoice.id, approved_at: approved_at})
               |> AuditedRepo.insert(user_map) do
          if action in [@approved_by_bn_invoice_status, @rejected_by_bn_invoice_status] do
            broadcast_to_poc_whatsapp(invoice, poc_approval)
          end

          invoice
        else
          {:error, reason} -> Repo.rollback(reason)
        end
      end)
    else
      nil -> {:error, :not_found}
      %LegalEntityPoc{} -> {:error, "You have been deactivated"}
      {:poc, false} -> {:error, "You can not update this invoice"}
    end
  end

  def all_invoices_for_poc(@approved_poc_invoice_flag, poc_id, role_type, limit, page_no) when role_type in [@legal_entity_poc_type_crm, @legal_entity_poc_type_finance] do
    offset = (page_no - 1) * limit
    approval = from(a in PocApprovals, order_by: [desc: a.inserted_at])

    Invoice
    |> join(:inner, [i], ap in assoc(i, :invoice_approvals))
    |> where([i, ap], ap.legal_entity_poc_id == ^poc_id and i.entity_type == ^@stories)
    |> group_by([i], i.id)
    |> preload([
      :broker,
      :legal_entity,
      :billing_company,
      invoice_approvals: ^{approval, :legal_entity_poc},
      billing_company: [:bank_account],
      booking_rewards_lead: [:invoices]
    ])
    |> order_by(desc: :updated_at)
    |> limit(^limit)
    |> offset(^offset)
    |> Repo.all()
    |> Enum.map(&invoice_map_for_poc/1)
  end

  def all_invoices_for_poc(@pending_poc_invoice_flag, poc_id, role_type, limit, page_no) when role_type in [@legal_entity_poc_type_crm, @legal_entity_poc_type_finance] do
    offset = (page_no - 1) * limit

    status = if role_type == @legal_entity_poc_type_finance, do: @approved_by_bn_invoice_status, else: @approved_by_finance

    Invoice
    |> join(:left, [i], l in assoc(i, :legal_entity))
    |> join(:inner, [i, l], pocm in LegalEntityPocMapping, on: pocm.legal_entity_id == l.id)
    |> join(:left, [i, l, pocm], poc in assoc(pocm, :legal_entity_poc))
    |> join(:left, [i, l], b in assoc(i, :broker))
    |> where(
      [i, l, pocm, poc, b],
      pocm.legal_entity_poc_id == ^poc_id and poc.active == true and pocm.active == true and i.status == ^status and b.role_type_id == 1 and i.entity_type == ^@stories
    )
    |> preload([
      :broker,
      :legal_entity,
      :billing_company,
      invoice_approvals: [:legal_entity_poc],
      billing_company: [:bank_account],
      booking_rewards_lead: [:invoices]
    ])
    |> order_by(desc: :updated_at)
    |> limit(^limit)
    |> offset(^offset)
    |> Repo.all()
    |> Enum.map(&invoice_map_for_poc/1)
  end

  def all_invoices_for_poc(_poc_id, @legal_entity_poc_type_admin, _limit, _page_no) do
    []
  end

  ## Private APIs
  defp can_poc_update_invoice_status?(poc, invoice) do
    poc = Repo.preload(poc, legal_entities: [:stories])

    poc.poc_type in [@legal_entity_poc_type_crm, @legal_entity_poc_type_finance] and
      Enum.any?(poc.legal_entities, fn entity ->
        Enum.any?(entity.stories, fn story -> not is_nil(invoice.story) and story.id == invoice.story.id end)
      end)
  end

  defp create_new_invoice(params, broker_id, organization_id, user_map) do
    entity_map = get_entity_id_and_type(params)
    is_created_by_piramal = Map.get(params, "is_created_by_piramal", false)
    proof_urls = Map.get(params, "proof_urls")
    is_advance_payment = Map.get(params, "is_advance_payment")
    payment_utr = Map.get(params, "payment_utr")
    change_notes = Map.get(params, "change_notes")
    invoice_pdf_url = Map.get(params, "invoice_pdf_url")

    status = parse_string(params["status"])
    lead_id = Map.get(params, "booking_rewards_id", nil)

    Invoice.changeset(
      %Invoice{},
      Map.merge(entity_map, %{
        status: status,
        invoice_number: params["invoice_number"],
        invoice_date: params["invoice_date"],
        broker_id: broker_id,
        legal_entity_id: parse_legal_entity_id(params["legal_entity_id"], nil),
        billing_company_id: params["billing_company_id"],
        is_created_by_piramal: is_created_by_piramal,
        booking_rewards_lead_id: lead_id,
        proof_urls: proof_urls,
        is_advance_payment: is_advance_payment,
        payment_utr: payment_utr,
        change_notes: change_notes,
        invoice_pdf_url: invoice_pdf_url,
        invoice_items: params["invoice_items"],
        old_broker_id: broker_id,
        old_organization_id: organization_id
      })
    )
    |> AuditedRepo.insert(user_map)
  end

  defp preload_invoice(nil), do: nil

  defp preload_invoice(invoice) do
    invoice
    |> preload_invoice_entity()
    |> Repo.preload([
      :broker,
      :legal_entity,
      :billing_company,
      :invoice_items,
      invoice_approvals: [:legal_entity_poc],
      billing_company: [:bank_account],
      booking_rewards_lead: [:invoices]
    ])
  end

  defp mark_invoice_as_paid(invoice, is_advance_payment, payment_utr, payment_mode, user_map) do
    invoice
    |> Invoice.changeset(%{
      status: @paid_invoice_status,
      is_advance_payment: is_advance_payment,
      payment_utr: payment_utr,
      payment_mode: payment_mode
    })
    |> AuditedRepo.update(user_map)
  end

  def add_tax_and_total_invoice_amount_dsa(invoice, loan_commission_percent) do
    loan_commission_percent = if is_binary(loan_commission_percent), do: loan_commission_percent |> String.to_float(), else: loan_commission_percent
    invoice = preload_invoice_entity(invoice)
    tds = if invoice.is_tds_valid == true, do: 0.20, else: 0.05
    hold_gst = invoice.hold_gst
    in_maharastra = invoice.broker.operating_city in @valid_cities_in_maharastra

    invoice_amount = LoanDisbursement.get_dsa_commission_amount(invoice.loan_disbursements, loan_commission_percent)
    amount_on_which_commission_is_given = LoanDisbursement.get_amount_on_commission_is_given(invoice.loan_disbursements)
    has_gst = not is_nil(invoice.billing_company.gst)
    cgst = float_round(invoice_amount * @cgst)
    sgst = float_round(invoice_amount * @sgst)

    igst = float_round(invoice_amount * @igst)


    payment_multiplier =
      cond do
        has_gst and hold_gst ->
          1 - tds
        has_gst and in_maharastra ->
          1 - tds + @cgst + @sgst
        has_gst ->
          1 - tds + @igst
        true ->
          1 - tds
      end

    pdf_multiplier =
      if has_gst do
        if in_maharastra, do: 1 + @cgst + @sgst - tds, else: 1 + @igst - tds
      else
        1 - tds
      end

      Map.merge(invoice, %{
        tds_percentage: tds,
        tds: float_round(invoice_amount * tds),
        cgst: cgst,
        sgst: sgst,
        igst: igst,
        cgst_display_value: if(has_gst and in_maharastra, do: cgst, else: "NA"),
        sgst_display_value: if(has_gst and in_maharastra, do: sgst, else: "NA"),
        igst_display_value: if(has_gst and not in_maharastra, do: igst, else: "NA"),
        net_payable: float_round(invoice_amount - invoice_amount * tds),
        total_invoice_amount: float_round(invoice_amount * payment_multiplier),
        total_invoice_amount_pdf: float_round(invoice_amount * pdf_multiplier),
        commission_percent: loan_commission_percent,
        in_maharastra: in_maharastra,
        invoice_amount: Utils.format_float(invoice_amount),
        amount_on_which_commission_is_given: amount_on_which_commission_is_given
      })
  end

  def generate_dsa_homeloan_invoice(invoice, user_map, params = %{"loan_commission" => loan_commission_percent}) do
    invoice_date_pdf = DateTime.from_unix!(invoice.invoice_date) |> Timex.Timezone.convert("Asia/Kolkata") |> DateTime.to_date()
    invoice = Map.put(invoice, :invoice_date_pdf, invoice_date_pdf)
    invoice = add_tax_and_total_invoice_amount_dsa(invoice, loan_commission_percent)
    has_gst = not is_nil(invoice.billing_company.gst)
    prefix = "dsa_homeloan_invoices"
    path = InvoiceHelper.get_path_for_dsa_homeloan_invoice(invoice, has_gst)

    s3_pdf_path = InvoiceHelper.upload_invoice(prefix, path, invoice.id)
    with imgix_pdf_url when not is_nil(imgix_pdf_url) <- InvoiceHelper.get_pdf_url(s3_pdf_path),
         {:ok, url} <- insert_invoice_pdf_url(Map.put(invoice, :invoice_date, invoice_date_pdf), imgix_pdf_url, user_map),
         {:ok, %LoanDisbursement{}} <- insert_loan_commission(invoice, invoice.invoice_amount, loan_commission_percent, user_map),
         {:ok, %Invoice{}} <- update_invoice_data(params, invoice, user_map) do
      {:ok, url}
    else
      nil -> {:error, "Something went wrong file generating invoice PDF."}
      {:error, error} -> {:error, error}
    end
  end

  def generate_dsa_homeloan_invoice(_invoice, _user_map, _params), do: {:error, "Loan Commission missing"}

  defp generate_advance_brokerage_invoice(invoice, user_map) do
    invoice_items = InvoiceItem.get_active_invoice_items_records(invoice.id)
    invoice = Map.put(invoice, :invoice_items, invoice_items)
    invoice_date = DateTime.from_unix!(invoice.invoice_date) |> Timex.Timezone.convert("Asia/Kolkata") |> DateTime.to_date()
    total_invoice_amount = get_total_invoice_amount(invoice.invoice_items)
    has_gst = not is_nil(invoice.billing_company.gst)
    multiplier = get_multiplier_for_total_invoice_amount(has_gst)
    total_invoice_amount_in_words = Utils.float_in_words(total_invoice_amount * multiplier) <> " Rupees"

    invoice =
      Map.merge(invoice, %{
        invoice_date: invoice_date,
        total_invoice_amount: total_invoice_amount,
        total_invoice_amount_in_words: total_invoice_amount_in_words
      })

    prefix = "advance_brokerage_invoices"
    path = InvoiceHelper.get_path_for_advance_brokerage_invoice(invoice, has_gst)
    s3_pdf_path = InvoiceHelper.upload_invoice(prefix, path, invoice.id)

    InvoiceHelper.get_pdf_url(s3_pdf_path)
    |> case do
      nil ->
        {:error, "Something went wrong file generating invoice PDF."}

      imgx_pdf_url ->
        insert_invoice_pdf_url(invoice, imgx_pdf_url, user_map)
    end
  end

  defp post_data_to_piramal(false, invoice), do: {:ok, invoice}

  defp post_data_to_piramal(true, invoice) do
    ExternalApiHelper.generate_sales_force_auth_token()
    |> case do
      {200, _response = %{"access_token" => bearer_token}} ->
        payment_date = NaiveDateTime.to_date(invoice.updated_at) |> Date.to_string()
        amount_paid = get_total_invoice_amount(invoice.invoice_items)

        body = %{
          BrokerageRecordId: invoice.invoice_number,
          Payment_to_Broker: "Done",
          Payment_date: payment_date,
          Amount_Paid: "#{amount_paid}",
          Payment_detail: invoice.payment_utr
        }

        {status, response} = ExternalApiHelper.post_data_to_piramal(body, bearer_token)
        parse_sfdc_response(status, response, invoice)

      {_, _response} ->
        {:error, "Something went wrong while generating sales force auth token for Piramal."}
    end
  end

  defp parse_sfdc_response(200, response, invoice) do
    Map.get(response, "returnCode", false)
    |> case do
      true ->
        {:ok, invoice}

      false ->
        {:error, Map.get(response, "message")}
    end
  end

  defp parse_sfdc_response(_, _response, _invoice),
    do: {:error, "Something went wrong while post data to Piramal SFDC."}

  defp deactivate_invoice_items(invoice, invoice_items, user_map) do
    current_active_invoice_items =
      InvoiceItem.get_active_invoice_items(invoice)
      |> Enum.map(fn invoice_item ->
        Map.get(invoice_item, "id")
      end)

    new_active_invoice_items =
      invoice_items
      |> Enum.map(fn invoice_item ->
        Map.get(invoice_item, "id")
      end)

    invoice_items_to_deactivate = current_active_invoice_items -- new_active_invoice_items

    invoice_items_to_deactivate
    |> Enum.each(fn invoice_item_id ->
      InvoiceItem.deactivate_invoice_item(invoice_item_id, user_map)
    end)
  end

  defp create_bank_account_params(
         account_holder_name,
         ifsc,
         bank_account_type,
         account_number,
         confirm_account_number,
         bank_name,
         cancelled_cheque
       ) do
    %{
      "account_holder_name" => account_holder_name,
      "ifsc" => ifsc,
      "bank_account_type" => bank_account_type,
      "account_number" => account_number,
      "confirm_account_number" => confirm_account_number,
      "bank_name" => bank_name,
      "cancelled_cheque" => cancelled_cheque
    }
  end

  defp create_billing_company_params(
         name,
         address,
         place_of_supply,
         company_type,
         pan,
         rera_id,
         bill_to_state,
         bill_to_pincode,
         bill_to_city,
         signature,
         email,
         gst,
         bank_account_params
       ) do
    %{
      "name" => name,
      "address" => address,
      "place_of_supply" => place_of_supply,
      "company_type" => company_type,
      "pan" => pan,
      "rera_id" => rera_id,
      "bill_to_state" => bill_to_state,
      "bill_to_pincode" => bill_to_pincode,
      "bill_to_city" => bill_to_city,
      "signature" => signature,
      "email" => email,
      "gst" => gst,
      "bank_account" => bank_account_params
    }
  end

  defp create_legal_entity_params(
         legal_entity_name,
         gst,
         pan,
         place_of_supply,
         sac,
         billing_address,
         state_code,
         shipping_address,
         ship_to_name
       ) do
    %{
      "legal_entity_name" => legal_entity_name,
      "gst" => gst,
      "pan" => pan,
      "place_of_supply" => place_of_supply,
      "sac" => sac,
      "billing_address" => billing_address,
      "state_code" => state_code,
      "shipping_address" => shipping_address,
      "ship_to_name" => ship_to_name
    }
  end

  defp create_invoice_items_params(
         brokerage_amount,
         agreement_value,
         building_name,
         customer_name,
         unit_number,
         wing_name
       ) do
    [
      %{
        "customer_name" => customer_name,
        "unit_number" => unit_number,
        "wing_name" => wing_name,
        "building_name" => building_name,
        "agreement_value" => agreement_value,
        "brokerage_amount" => brokerage_amount
      }
    ]
  end

  defp create_invoice_params(
         status,
         invoice_number,
         legal_entity_id,
         billing_company_id,
         invoice_items,
         is_created_by_piramal
       ) do
    invoice_date = Time.naive_to_epoch_in_sec(DateTime.utc_now())

    %{
      "status" => status,
      "invoice_number" => invoice_number,
      "invoice_date" => invoice_date,
      "legal_entity_id" => legal_entity_id,
      "billing_company_id" => billing_company_id,
      "invoice_items" => invoice_items,
      "is_created_by_piramal" => is_created_by_piramal
    }
  end

  defp get_invoices_by_broker_id_query(broker_id, 1, 1, org_id, status, search_text) do
    Invoice
    |> join(:inner, [inv], br in Broker, on: inv.broker_id == br.id)
    |> join(:inner, [inv, br], cred in Credential, on: br.id == cred.broker_id)
    |> where([inv, br, cred], cred.organization_id == ^org_id)
    |> filter_by_search_text(search_text)
    |> get_status_query_for_broker(status, BrokerRole.admin().id, Broker.real_estate_broker()["id"])
    |> maybe_show_draft_invoices_for_broker_only(broker_id, status)
  end

  defp get_invoices_by_broker_id_query(broker_id, broker_role_id, role_type_id, _org_id, status, search_text) do
    Invoice
    |> join(:inner, [inv], br in Broker, on: inv.broker_id == br.id)
    |> where([inv, br], inv.broker_id == ^broker_id)
    |> filter_by_search_text(search_text)
    |> get_status_query_for_broker(status, broker_role_id, role_type_id)
  end

  defp get_invoice_for_broker_by_uuid(uuid, broker_id) do
    Invoice
    |> preload([
      :broker,
      :legal_entity,
      :billing_company,
      billing_company: [:bank_account],
      booking_rewards_lead: [:invoices]
    ])
    |> where([inv], inv.broker_id == ^broker_id and inv.uuid == ^uuid)
    |> Repo.one()
    |> preload_invoice_entity()
  end

  def insert_invoice_pdf_url(invoice, imgx_pdf_url, user_map) do
    old_invoice_url = invoice.invoice_pdf_url

    invoice
    |> Invoice.changeset(%{invoice_pdf_url: imgx_pdf_url})
    |> AuditedRepo.update(user_map)
    |> case do
      {:ok, _changeset} ->
        Task.async(fn -> delete_old_invoice(old_invoice_url) end)
        {:ok, imgx_pdf_url}

      {:error, error} ->
        {:error, error}
    end
  end

  def insert_loan_commission(invoice, loan_commission, loan_commission_percent, user_map) do
    Repo.get_by(LoanDisbursement, id: invoice.entity_id)
    |> LoanDisbursement.changeset(%{loan_commission: loan_commission, commission_percentage: loan_commission_percent})
    |> AuditedRepo.update(user_map)
  end

  def update_invoice_data(params, invoice ,user_map) do
    employee_role_id = params["employee_role_id"]
    total_invoice_amount = if(not is_nil(invoice.total_invoice_amount)) do
      if(is_binary(invoice.total_invoice_amount), do: String.to_float(invoice.total_invoice_amount), else: invoice.total_invoice_amount)
    else
      invoice.total_invoice_amount
    end

    status =
      case employee_role_id do
        nil ->
          invoice.status

        @dsa_super_role_id ->
          "pending_from_super"

        @dsa_admin_role_id ->
          "approved_by_admin"

        @dsa_finance_role_id ->
          "approved_by_super"
      end

    invoice
    |> Invoice.changeset(%{status: status, total_payable_amount: total_invoice_amount})
    |> AuditedRepo.update(user_map)
  end

  defp delete_old_invoice(nil), do: {:ok, ""}

  defp delete_old_invoice(file_url) do
    s3_path = parse_file_url(String.contains?(file_url, @imgix_domain), file_url)
    if is_nil(s3_path), do: {:ok, ""}, else: S3Helper.delete_file(s3_path)
  end

  defp parse_file_url(false, _file_url), do: nil
  defp parse_file_url(true, file_url), do: String.replace(file_url, @imgix_domain <> "/", "")

  defp parse_string(nil), do: nil
  defp parse_string(string), do: string |> String.trim() |> String.downcase()

  defp get_status_query_for_broker(query, nil, 1, 1), do: query |> where([inv], inv.status not in [@deleted_status, @admin_review_pending])
  defp get_status_query_for_broker(query, "", 1, 1), do: query |> where([inv], inv.status not in [@deleted_status, @admin_review_pending])
  defp get_status_query_for_broker(query, nil, _broker_role_id, _role_type_id), do: query |> where([inv], inv.status != @deleted_status)
  defp get_status_query_for_broker(query, "", _broker_role_id, _role_type_id), do: query |> where([inv], inv.status != @deleted_status)
  defp get_status_query_for_broker(query, @approved_by_bn_invoice_status, _broker_role_id, _role_type_id), do: query |> where([inv], inv.status == @approved_by_crm)
  defp get_status_query_for_broker(query, @paid_invoice_status, _broker_role_id, _role_type_id), do: query |> where([inv], inv.status == @paid_invoice_status)
  defp get_status_query_for_broker(query, @draft_status, _broker_role_id, _role_type_id), do: query |> where([inv], inv.status == @draft_status)
  defp get_status_query_for_broker(query, @admin_review_pending, _broker_role_id, _role_type_id), do: query |> where([inv], inv.status == @admin_review_pending)

  defp get_status_query_for_broker(query, @approval_pending, 2, 1),
    do: query |> where([inv], inv.status in [@approval_pending, @changes_requested_invoice_status, @admin_review_pending, @approved_by_bn_invoice_status, @approved_by_finance])

  defp get_status_query_for_broker(query, @approval_pending, _broker_role_id, _role_type_id),
    do: query |> where([inv], inv.status in [@approval_pending, @changes_requested_invoice_status, @approved_by_bn_invoice_status, @approved_by_finance])

  defp get_status_query_for_broker(query, @changes_requested_invoice_status, _broker_role_id, _role_type_id),
    do: query |> where([inv], inv.status == @changes_requested_invoice_status)

  defp get_status_query_for_broker(query, "rejected", _broker_role_id, _role_type_id),
    do: query |> where([inv], inv.status in [@rejected_by_bn_invoice_status, @rejected_by_admin, @rejected_by_finance, @rejected_by_crm])

  defp get_status_query_for_broker(query, _, 1, 1), do: query |> where([inv], inv.status not in [@deleted_status, @admin_review_pending])
  defp get_status_query_for_broker(query, _, _broker_role_id, _role_type_id), do: query |> where([inv], inv.status != @deleted_status)

  defp maybe_show_draft_invoices_for_broker_only(query, broker_id, @draft_status), do: query |> where([inv], inv.broker_id == ^broker_id)
  defp maybe_show_draft_invoices_for_broker_only(query, _broker_id, _status), do: query

  defp get_status_query(nil, _), do: Invoice |> where([inv], inv.status not in [@draft_status, @deleted_status, @admin_review_pending, @rejected_by_admin])
  defp get_status_query("", _), do: Invoice |> where([inv], inv.status not in [@draft_status, @deleted_status, @admin_review_pending, @rejected_by_admin])

  defp get_status_query(status, employee_role_id) do
    status =
      cond do
        status == @rejected_by_bn_invoice_status -> @rejected_status_list
        status == @approved_by_bn_invoice_status -> [@approved_by_bn_invoice_status, @approved_by_finance, @approved_by_crm]
        status == @invoice_requested -> [@invoice_requested, @approved_by_admin]
        status == @approved_by_super and employee_role_id == 29 -> [@approved_by_super, @approved_by_finance]
        true -> [status]
      end

    Invoice |> where([inv], inv.status not in [@draft_status, @deleted_status] and inv.status in ^status)
  end

  defp get_paginated_results(
         page_no,
         limit,
         status,
         project_name,
         broker_phone_number,
         developer_name,
         is_enabled_for_commercial,
         broker_name,
         billing_company_name,
         emp_id,
         emp_role_id
       ) do
    offset = (page_no - 1) * limit
    type = get_type_from_role(emp_role_id)

    query =
      get_status_query(status, emp_role_id)
      |> where([inv], inv.type in ^type)
      |> filter_by_broker(broker_phone_number)
      |> filter_by_broker_name(broker_name)
      |> filter_by_project(project_name, is_enabled_for_commercial)
      |> filter_by_developer(developer_name)
      |> filter_by_billing_company(billing_company_name)
      |> filter_by_employee_ids(emp_id, emp_role_id, type)

    invoices =
      query
      |> preload([
        :broker,
        :approved_by_super,
        :legal_entity,
        :billing_company,
        invoice_approvals: [:legal_entity_poc],
        billing_company: [:bank_account],
        booking_rewards_lead: [:invoices]
      ])
      |> order_by(desc: :updated_at)
      |> limit(^limit)
      |> offset(^offset)
      |> Repo.all()

    invoices_map =
      invoices
      |> Enum.map(fn invoice ->
        invoice = preload_invoice_entity(invoice)
        invoice_items_map = InvoiceItem.get_active_invoice_items(invoice)
        create_invoice_map(invoice, invoice_items_map)
      end)

    %{
      "invoices" => invoices_map,
      "next_page_exists" => Enum.count(invoices) >= limit,
      "next_page_query_params" => "p=#{page_no + 1}"
    }
  end

  defp filter_by_project(query, project_name, is_enabled_for_commercial) do
    query =
      if is_binary(project_name) or is_enabled_for_commercial == "true" do
        query
        |> join(:left, [inv], s in Story, on: s.id == inv.entity_id and inv.entity_type == @stories)
      else
        query
      end

    query =
      if is_binary(project_name) do
        project_name = "%" <> project_name <> "%"

        query
        |> where([inv, ..., s], ilike(s.name, ^project_name))
      else
        query
      end

    query =
      if is_enabled_for_commercial == "true" do
        query |> where([inv, ..., s], s.is_enabled_for_commercial == true)
      else
        query
      end

    query
  end

  defp filter_by_broker(query, phone_number) when is_bitstring(phone_number) do
    query
    |> join(:left, [inv], br in assoc(inv, :broker))
    |> join(:left, [inv, br], cred in assoc(br, :credentials))
    |> where([inv, br, cred], cred.phone_number == ^phone_number)
  end

  defp filter_by_broker(query, _phone_number), do: query

  defp filter_by_developer(query, developer_name) when is_binary(developer_name) do
    developer_name = "%" <> developer_name <> "%"

    query
    |> join(:left, [inv], s in Story, on: s.id == inv.entity_id and inv.entity_type == @stories)
    |> join(:left, [b, ..., s], d in assoc(s, :developer))
    |> where([b, ..., d], ilike(d.name, ^developer_name))
  end

  defp filter_by_developer(query, _developer_name), do: query

  defp filter_by_broker_name(query, ""), do: query

  defp filter_by_broker_name(query, broker_name) when is_binary(broker_name) do
    broker_name = "%" <> broker_name <> "%"

    query
    |> join(:left, [inv], br in assoc(inv, :broker))
    |> where([inv, br], ilike(br.name, ^broker_name))
  end

  defp filter_by_broker_name(query, _broker_name), do: query

  defp filter_by_billing_company(query, name) when name in [nil, ""], do: query

  defp filter_by_billing_company(query, name) do
    company_name = "%" <> name <> "%"

    query
    |> join(:left, [inv], c in assoc(inv, :billing_company))
    |> where([inv, ..., c], ilike(c.name, ^company_name))
  end

  defp get_total_invoice_amount(nil), do: 0

  defp get_total_invoice_amount(invoice_items) do
    invoice_items
    |> Enum.map(fn invoice_item ->
      value = Map.get(invoice_item, "brokerage_amount")
      Map.get(invoice_item, :brokerage_amount, value)
    end)
    |> Enum.sum()
  end

  defp get_multiplier_for_total_invoice_amount(true), do: 1 + @cgst + @sgst - @tds - @tcs
  defp get_multiplier_for_total_invoice_amount(false), do: 1 - @tds

  def get_invoice_display_status_text(status, invoice_approvals, lead_id, type \\ nil) do
    cond do
      status in [@approved_by_finance, @approval_pending, @approved_by_bn_invoice_status] ->
        @approval_pending_invoice_display_text

      status == "changes_requested" ->
        @changes_requested_display_text

      status == "invoice_requested" ->
        @invoice_requested_display_text

      status in ["draft", "deleted"] ->
        String.capitalize(status)

      status in @rejected_status_list ->
        "Rejected"

      status == "paid" and type == Invoice.type_dsa() ->
        "Paid"

      status == "paid" and is_nil(lead_id) == false ->
        "10K reward collected"

      status == "paid" ->
        "5K reward collected"

      status == "admin_review_pending" ->
        "Admin review pending"

      status == "rejected_by_admin" ->
        "Rejected by admin"

      status == @approved_by_crm ->
        crm = Enum.find(invoice_approvals, &(String.downcase(&1["role_type"]) == "crm"))

        if not is_nil(crm) do
          updated_at = Time.epoch_to_naive(crm["approved_at"] * 1000) |> Timex.Timezone.convert("Asia/Kolkata")
          "Approved on " <> Utils.get_month_name_by_month_number(updated_at.month) <> " #{updated_at.day}"
        else
          "Approved"
        end

      status in ["approved_by_admin", "pending_from_super", "approved_by_super"] ->
        "Approval Pending"

      status == "approved_by_finance" ->
        "Approved"

      status == "payment_in_progress" ->
        "Payment In Progress"

      status == "payment_failed" ->
        "Payment Failed"

      true ->
        "Invalid invoice status"
    end
  end

  defp get_display_amount("dsa", invoice, _invoice_items), do: invoice.loan_disbursements.loan_commission
  defp get_display_amount("booking_reward", invoice, _invoice_items), do: invoice.bonus_amount
  defp get_display_amount("brokerage", _invoice, invoice_items), do: get_display_amount_for_invoice(invoice_items)

  defp get_display_amount_for_invoice(nil), do: 0
  defp get_display_amount_for_invoice([]), do: 0

  defp get_display_amount_for_invoice(invoice_items) do
    invoice_items
    |> Enum.map(fn invoice_item ->
      Map.get(invoice_item, "brokerage_amount")
    end)
    |> Enum.sum()
  end

  defp get_multiplier_for_display_amount(true), do: Float.round(1 + @cgst + @sgst, 2)
  defp get_multiplier_for_display_amount(false), do: 1.00

  defp parse_display_amount(nil), do: "0"

  defp parse_display_amount(amount),
    do: if(is_float(amount), do: :erlang.float_to_binary(amount, decimals: 2), else: to_string(amount))

  defp create_invoice_map(nil, _invoice_items), do: nil

  defp create_invoice_map(invoice, invoice_items) do
    broker_map = Broker.create_broker_map(invoice.broker)
    entity_map = create_invoice_entity_map(invoice)

    legal_entity_map = LegalEntity.create_legal_entity_map(invoice.legal_entity)
    legal_entity_pocs = LegalEntityPocMapping.get_legal_entity_pocs_for_legal_entity(Map.get(legal_entity_map, "id"))
    legal_entity_map = Map.put(legal_entity_map, :legal_entity_pocs, legal_entity_pocs)

    billing_company_map = BillingCompany.create_billing_company_map(invoice.billing_company)
    bank_account = BankAccount.create_bank_account_map(invoice.billing_company.bank_account)
    billing_company_map = Map.put(billing_company_map, :bank_account, bank_account)

    booking_invoice = BookingInvoice.get_booking_invoice_by_invoice_id(invoice.id)
    booking_invoice_pdf_url = if is_nil(booking_invoice), do: nil, else: booking_invoice.booking_invoice_pdf_url

    booking_rewards_lead_uuid = if invoice.booking_rewards_lead_id, do: invoice.booking_rewards_lead.uuid, else: nil

    invoice_expire_in =
      if not is_nil(invoice.booking_rewards_lead_id) and invoice.booking_rewards_lead.approved_at do
        invoice.booking_rewards_lead.approved_at
        |> Timex.add(Timex.Duration.from_days(90))
        |> Time.naive_to_epoch_in_sec()
      end

    display_amount = get_display_amount(invoice.type, invoice, invoice_items)
    has_gst = not is_nil(invoice.billing_company.gst)
    multiplier = get_multiplier_for_display_amount(has_gst)
    display_amount = if not is_nil(display_amount), do: (display_amount * multiplier) |> parse_display_amount(), else: nil

    invoice_approvals = invoice_approvals_map(invoice)
    status_change_logs = status_change_logs(invoice.id)
    invoice_payout  = InvoicePayout.get_invoice_payout(invoice.id)

    %{
      "id" => invoice.id,
      "uuid" => invoice.uuid,
      "status" => invoice.status,
      "invoice_number" => invoice.invoice_number,
      "invoice_date" => invoice.invoice_date,
      "invoice_pdf_url" => invoice.invoice_pdf_url,
      "broker_id" => invoice.broker_id,
      "legal_entity_id" => invoice.legal_entity_id,
      "billing_company_id" => invoice.billing_company_id,
      "broker" => broker_map,
      "legal_entity" => legal_entity_map,
      "billing_company" => billing_company_map,
      "invoice_items" => invoice_items,
      "booking_invoice_pdf_url" => booking_invoice_pdf_url,
      "is_created_by_piramal" => invoice.is_created_by_piramal,
      "created_at" => Time.naive_to_epoch_in_sec(invoice.inserted_at),
      "proof_urls" => invoice.proof_urls,
      "change_notes" => invoice.change_notes,
      "is_advance_payment" => invoice.is_advance_payment,
      "payment_utr" => invoice.payment_utr,
      "type" => invoice.type,
      "bonus_amount" => invoice.bonus_amount,
      "booking_rewards_lead_uuid" => booking_rewards_lead_uuid,
      "invoice_expire_in" => invoice_expire_in,
      "invoice_status_display_text" => get_invoice_display_status_text(invoice.status, invoice_approvals, invoice.booking_rewards_lead_id, invoice.type),
      "payment_mode" => invoice.payment_mode,
      "display_amount" => display_amount,
      "enable_edit" => enable_edit(invoice),
      "invoice_approvals" => invoice_approvals,
      "entity_id" => invoice.entity_id,
      "simplified_status" => get_simplified_status_message(invoice.status),
      "bn_commission" => invoice.bn_commission,
      "is_billed" => invoice.is_billed,
      "billing_number" => invoice.billing_number,
      "rejection_reason" => invoice.rejection_reason,
      "remarks" => invoice.remarks,
      "all_remarks" => InvoiceRemarks.get_invoice_remarks(invoice.id),
      "payment_received" => invoice.payment_received,
      "is_tds_valid" => invoice.is_tds_valid,
      "status_change_logs" => status_change_logs,
      "gst_filling_status" => invoice.gst_filling_status,
      "invoice_payout" => invoice_payout,
      "hold_gst" => invoice.hold_gst,
      "approved_by_super_details" =>
        if(Ecto.assoc_loaded?(invoice.approved_by_super) and not is_nil(invoice.approved_by_super_id),
          do: %{"name" => invoice.approved_by_super.name, "phone_number" => invoice.approved_by_super.phone_number},
          else: %{}
        )
    }
    |> maybe_merge_hl_lead_details(invoice.type)
    |> Map.merge(entity_map)
  end

  defp status_change_logs(invoice_id) do
    Log
    |> join(:inner, [l], e in EmployeeCredential, on: e.id == l.user_id and l.user_type == "Employee")
    |> where([l, e], fragment("(changes ->> 'status') is not null"))
    |> where([l, e], l.entity_id == ^invoice_id and l.entity_type == "invoices")
    |> order_by([l, e], desc: l.inserted_at)
    |> select([l, e], %{
      emp_name: e.name,
      phone_number: e.phone_number,
      status: fragment("changes ->> 'status'"),
      inserted_at: l.inserted_at
    })
    |> Repo.all()
  end

  defp get_simplified_status_message(status) do
    cond do
      status in [@approval_pending, @approved_by_bn_invoice_status, @approved_by_finance] -> @approval_pending
      status in [@rejected_by_bn_invoice_status, @rejected_by_finance, @rejected_by_crm] -> @rejected_by_bn_invoice_status
      status == @approved_by_crm -> @approved_by_bn_invoice_status
      true -> status
    end
  end

  def can_override_invoice?(invoice) do
    legal_entity_pocs = LegalEntityPocMapping.get_legal_entity_pocs_for_legal_entity(invoice.legal_entity_id)

    if length(legal_entity_pocs) > 2 do
      not invoice.is_created_by_piramal and invoice.status == "approved" and invoice.entity_type == :stories and invoice.type == "brokerage" and
        invoice.updated_at < override_threshold_days_ago()
    else
      true
    end
  end

  defp override_threshold_days_ago() do
    NaiveDateTime.utc_now()
    |> Timex.shift(days: @override_after_days)
  end

  defp maybe_merge_hl_lead_details(invoice_details, invoice_type) when invoice_type != "dsa", do: invoice_details

  defp maybe_merge_hl_lead_details(invoice_details, invoice_type) when invoice_type == "dsa" do
    disbursement_id = invoice_details["entity_id"]
    disbursement = Repo.get_by(LoanDisbursement, id: disbursement_id) |> Repo.preload([:homeloan_lead, :invoice, :loan_file])
    employment_type = LeadType.employment_type_list() |> Enum.find(&(&1.id == disbursement.homeloan_lead.employment_type)) || %{}
    commission_on = get_commission_on(disbursement)

    lead_details = %{
      "lead_id" => disbursement.homeloan_lead.id,
      "name" => disbursement.homeloan_lead.name,
      "remarks" => disbursement.homeloan_lead.remarks,
      "display_required_loan_amount" => Utils.format_money_new(disbursement.homeloan_lead.loan_amount),
      "phone_number" => disbursement.homeloan_lead.phone_number,
      "employment_type" => disbursement.homeloan_lead.employment_type,
      "employment_type_name" => employment_type |> Map.get(:name),
      "is_last_status_seen" => disbursement.homeloan_lead.is_last_status_seen,
      "channel_url" => disbursement.homeloan_lead.channel_url,
      "lead_creation_date" => disbursement.homeloan_lead.lead_creation_date,
      "lead_created_date_unix" => Time.naive_to_epoch_in_sec(disbursement.homeloan_lead.inserted_at),
      "bank_name" => disbursement.homeloan_lead.bank_name,
      "branch_name" => disbursement.homeloan_lead.branch_name,
      "fully_disbursed" => disbursement.homeloan_lead.fully_disbursed,
      "loan_type" => disbursement.homeloan_lead.loan_type,
      "property_stage" => disbursement.homeloan_lead.property_stage,
      "processing_type" => disbursement.homeloan_lead.processing_type,
      "application_id" => disbursement.homeloan_lead.application_id,
      "bank_rm" => disbursement.homeloan_lead.bank_rm,
      "bank_rm_phone_number" => disbursement.homeloan_lead.bank_rm_phone_number,
      "sanctioned_amount" => disbursement.homeloan_lead.sanctioned_amount,
      "display_sanctioned_amount" => Utils.format_money_new(disbursement.homeloan_lead.sanctioned_amount),
      "rejected_lost_reason" => disbursement.homeloan_lead.rejected_lost_reason,
      "property_type" => disbursement.homeloan_lead.property_type,
      "pan" => disbursement.homeloan_lead.pan,
      "loan_subtype" => disbursement.homeloan_lead.loan_subtype
    }

    loan_file_details = %{
      "loan_file_id" => if(is_nil(disbursement.loan_file), do: nil, else: disbursement.loan_file.id),
      "bank_id" => if(is_nil(disbursement.loan_file), do: nil, else: disbursement.loan_file.bank_id),
      "bank_name" => if(is_nil(disbursement.loan_file), do: nil, else: Bank.get_bank_name_from_id(disbursement.loan_file.bank_id)),
      "branch_location" => if(is_nil(disbursement.loan_file), do: nil, else: disbursement.loan_file.branch_location),
      "application_id" => if(is_nil(disbursement.loan_file), do: nil, else: disbursement.loan_file.application_id),
      "bank_rm_name" => if(is_nil(disbursement.loan_file), do: nil, else: disbursement.loan_file.bank_rm_name),
      "bank_rm_phone_number" => if(is_nil(disbursement.loan_file), do: nil, else: disbursement.loan_file.bank_rm_phone_number),
      "sanctioned_amount" => if(is_nil(disbursement.loan_file), do: nil, else: disbursement.loan_file.sanctioned_amount),
      "display_sanctioned_amount" => if(is_nil(disbursement.loan_file), do: nil, else: Utils.format_money_new(disbursement.loan_file.sanctioned_amount)),
      "sanctioned_doc_url" => if(is_nil(disbursement.loan_file), do: nil, else: S3Helper.get_imgix_url(disbursement.loan_file.sanctioned_doc_url)),
      "sanctioned_doc_key" => if(is_nil(disbursement.loan_file), do: nil, else: disbursement.loan_file.sanctioned_doc_url),
      "s3_prefix_url" => ApplicationHelper.get_imgix_domain(),
      "bank_offer_doc_key" => if(is_nil(disbursement.loan_file), do: nil, else: disbursement.loan_file.bank_offer_doc_url),
      "bank_offer_doc_url" => if(is_nil(disbursement.loan_file), do: nil, else: S3Helper.get_imgix_url(disbursement.loan_file.bank_offer_doc_url)),
      "original_agreement_doc_url" => if(is_nil(disbursement.loan_file), do: nil, else: S3Helper.get_imgix_url(disbursement.loan_file.original_agreement_doc_url)),
      "loan_insurance_done" => if(is_nil(disbursement.loan_file), do: nil, else: disbursement.loan_file.loan_insurance_done),
      "loan_insurance_amount" => if(is_nil(disbursement.loan_file), do: nil, else: disbursement.loan_file.loan_insurance_amount),
      "display_loan_insurance_amount" => if(is_nil(disbursement.loan_file), do: nil, else: Utils.format_money_new(disbursement.loan_file.loan_insurance_amount)),
      "inserted_at" => if(is_nil(disbursement.loan_file), do: nil, else: disbursement.loan_file.inserted_at |> Time.naive_to_epoch_in_sec()),
      "commission_on" => commission_on
    }

    loan_disbursements = %{
      "disbursement_id" => disbursement.id,
      "lan" => disbursement.lan,
      "disbursement_date" => disbursement.disbursement_date,
      "loan_disbursed" => disbursement.loan_disbursed,
      "loan_commission" => Utils.format_float(disbursement.loan_commission),
      "loan_commission_percent" => disbursement.commission_percentage,
      "display_loan_disbursed" => Utils.format_money_new(disbursement.loan_disbursed),
      "display_loan_commission" => Utils.format_money_new(disbursement.loan_commission),
      "invoice_id" => disbursement.invoice_id,
      "disbursement_type" => disbursement.disbursement_type,
      "document_url" => S3Helper.get_imgix_url(disbursement.document_url),
      "otc_cleared" => disbursement.otc_cleared,
      "pdd_cleared" => disbursement.pdd_cleared,
      "disbursed_with" => disbursement.disbursed_with,
      "otc_pdd_proof_doc" => S3Helper.get_imgix_url(disbursement.otc_pdd_proof_doc),
      "invoice_pdf_url" => if(not is_nil(disbursement.invoice), do: disbursement.invoice.invoice_pdf_url, else: nil),
      "invoice_number" => if(not is_nil(disbursement.invoice), do: disbursement.invoice.invoice_number, else: nil),
      "invoice_date" => if(not is_nil(disbursement.invoice), do: disbursement.invoice.invoice_date, else: nil),
      "loan_commission_paid" => if(not is_nil(disbursement.invoice) and disbursement.invoice.status == "paid", do: true, else: false),
      "invoice_status" => if(not is_nil(disbursement.invoice), do: disbursement.invoice.status, else: nil),
      "inserted_at" => disbursement.inserted_at,
      "commission_applicable_amount" => disbursement.commission_applicable_amount
    }

    Map.merge(invoice_details, %{"lead_details" => lead_details, "loan_disbursements" => loan_disbursements, "loan_file_details" => loan_file_details})
  end

  def get_commission_on(disbursement) do
    if(not is_nil(disbursement.commission_applicable_on)) do
      disbursement.commission_applicable_on
    else
      if(is_nil(disbursement.loan_file), do: nil, else: Atom.to_string(Bank.get_commission_on_from_id(disbursement.loan_file.bank_id)))
    end
  end

  defp add_invoice_wallet_amount_to_map(invoice, map, type),
    do: Map.put(map, type, get_amount_to_be_deducted_from_wallet(invoice) + Map.get(map, type, 0))

  defp get_amount_to_be_deducted_from_wallet(invoice = %{type: "booking_reward"}), do: invoice.bonus_amount || 0
  defp get_amount_to_be_deducted_from_wallet(invoice = %{type: "brokerage"}), do: invoice.booking_invoice.invoice_amount || 0

  def valid_wallet_balance?(invoice = %{booking_rewards_lead_id: lead_id}) when not is_nil(lead_id) do
    invoice = invoice |> Repo.preload([:booking_invoice, story: [:payouts]])
    balances = Story.get_story_balances(invoice.story)
    available_balance = balances[:total_credits_amount] - balances[:total_debits_amount] - balances[:total_approved_amount]

    case invoice.type do
      @invoice_type_brokerage -> available_balance >= invoice.booking_invoice.invoice_amount
      @invoice_type_booking_reward -> available_balance >= invoice.bonus_amount
    end
  end

  def valid_wallet_balance?(_invoice), do: true

  defp send_changes_requested_fcm_notification(invoice, change_notes) do
    invoice = invoice |> Repo.preload(broker: :credentials)
    cred = Utils.get_active_fcm_credential(invoice.broker.credentials)
    send_fcm_notification(cred, invoice, change_notes)
  end

  defp send_fcm_notification(nil, _invoice, _change_notes), do: nil

  defp send_fcm_notification(cred, invoice, change_notes) do
    data = %{
      type: "INVOICE_CHANGE_REQUESTED",
      data: %{
        invoice_uuid: invoice.uuid,
        title: "Invoice Change Requested",
        message: change_notes
      }
    }

    Exq.enqueue(Exq, "send_changes_requested_fcm_notification", BnApis.Notifications.PushNotificationWorker, [
      cred.fcm_id,
      data,
      cred.id,
      cred.notification_platform
    ])
  end

  defp enable_edit(%{type: "brokerage"} = invoice),
    do:
      is_nil(invoice.booking_rewards_lead_id) and
        invoice.status in ~w(draft changes_requested approval_pending)

  defp enable_edit(_invoice), do: false

  def generate_signed_tnc(inv_uuid, aadhar_num, email_id) do
    case get_invoice_by_uuid(inv_uuid) do
      nil ->
        {:error, :not_found}

      invoice ->
        amount = get_total_invoice_amount(invoice.invoice_items)
        pdf_map = InvoiceHelper.create_map_for_tnc_pdf(invoice, aadhar_num, email_id, amount)
        InvoiceHelper.generate_signed_tnc_pdf(pdf_map)
    end
  end

  defp get_entity_id_and_type(%{"story_id" => id}) when not is_nil(id), do: %{entity_id: id, entity_type: @stories, type: Invoice.type_brokerage()}
  defp get_entity_id_and_type(%{"loan_disbursements_id" => id}) when not is_nil(id), do: %{entity_id: id, entity_type: @loan_disbursements, type: Invoice.type_dsa()}
  defp get_entity_id_and_type(%{"is_created_by_piramal" => true}), do: %{type: Invoice.type_brokerage()}
  defp get_entity_id_and_type(_params), do: %{}

  defp create_invoice_entity_map(%{entity_type: @stories, story: story} = invoice),
    do: %{
      "story_id" => invoice.entity_id,
      "story" => Story.create_story_map(story)
    }

  defp create_invoice_entity_map(%{entity_type: @loan_disbursements, loan_disbursements: loan}),
    do: %{
      "loan_disbursement" => %{
        "homeloan_lead_id" => loan.homeloan_lead.id,
        "name" => loan.homeloan_lead.name
      }
    }

  defp create_invoice_entity_map(_inoice), do: %{}

  defp from_entity_type_to_key(@stories), do: :story
  defp from_entity_type_to_key(@loan_disbursements), do: @loan_disbursements

  def float_round(value) do
    if is_integer(value) do
      value
    else
      Float.round(value, 2) |> :erlang.float_to_binary(decimals: 2)
    end
  end

  defp parse_legal_entity_id("bn", _default), do: LegalEntity.get_bn_details().id
  defp parse_legal_entity_id(nil, default), do: default
  defp parse_legal_entity_id(value, _default), do: value

  defp can_user_update_invoice?(%Invoice{type: "dsa"} = invoice, @dsa_admin_role_id, emp_id) do
    agent_id = LoanDisbursement.get_employee_id_related_to_lead(invoice.loan_disbursements.id)
    is_nil(agent_id) == false and agent_id in EmployeeCredential.get_all_assigned_employee_for_an_employee(emp_id)
  end

  defp can_user_update_invoice?(%Invoice{type: "dsa"} = invoice, @dsa_super_role_id, emp_id) do
    agent_id = LoanDisbursement.get_employee_id_related_to_lead(invoice.loan_disbursements.id)
    reporter_ids = EmployeeCredential.get_all_assigned_employee_for_an_employee(emp_id)
    agent_id in reporter_ids
  end

  defp can_user_update_invoice?(_invoice, _role_id, _emp_id), do: true

  defp filter_by_employee_ids(query, emp_id, emp_role_id, types) do
    if Invoice.type_dsa() in types and emp_role_id != EmployeeRole.dsa_finance()[:id] do
      ids = EmployeeCredential.get_all_assigned_employee_for_an_employee(emp_id)

      query
      |> join(:left, [i], l in LoanDisbursement, on: i.entity_id == l.id)
      |> join(:left, [i, ..., l], le in Lead, on: le.id == l.homeloan_lead_id)
      |> where([i, ..., le], le.employee_credentials_id in ^ids)
    else
      query
    end
  end

  defp get_type_from_role(employee_role_id) do
    if employee_role_id in [EmployeeRole.dsa_admin()[:id], EmployeeRole.dsa_super()[:id], EmployeeRole.dsa_agent()[:id], EmployeeRole.dsa_finance()[:id]] do
      [Invoice.type_dsa()]
    else
      [Invoice.type_reward(), Invoice.type_brokerage()]
    end
  end

  defp update_invoice_id_in_loan_disbursement(%Invoice{type: "dsa", id: id, entity_id: entity_id}) do
    LoanDisbursement.update_invoice_id(entity_id, id)
  end

  defp update_invoice_id_in_loan_disbursement(_invoice), do: {1, nil}

  defp can_create_invoice?(%{"loan_disbursements_id" => id}, broker_id) do
    count =
      Invoice
      |> where([i], i.entity_id == ^id and i.entity_type == ^@loan_disbursements and i.type == ^Invoice.type_dsa() and i.broker_id == ^broker_id)
      |> Repo.aggregate(:count, :id)

    count <= 1
  end

  defp can_create_invoice?(_invoice, _broker_id), do: true

  defp create_invoice_map_for_broker(invoice, invoice_items_map, broker_id) do
    invoice_map = create_invoice_map(invoice, invoice_items_map)
    Map.put(invoice_map, "enable_edit", invoice_map["enable_edit"] and invoice.broker_id == broker_id)
  end

  defp maybe_send_notification_to_admins(2, 1, org_id) do
    Credential
    |> where([cred], cred.organization_id == ^org_id and cred.broker_role_id == 1)
    |> Repo.all()
    |> Enum.each(fn x -> send_new_invoice_created_notification(x) end)
  end

  defp maybe_send_notification_to_admins(_broker_role_id, _role_type_id, _org_id), do: :ok

  defp invoice_approvals_map(invoice) do
    Enum.map(invoice.invoice_approvals, fn action ->
      %{
        "id" => action.legal_entity_poc.id,
        "name" => action.legal_entity_poc.poc_name,
        "approved_at" => action.approved_at,
        "role_type" => action.role_type,
        "action" => action.action
      }
    end)
  end

  defp invoice_map_for_poc(invoice) do
    invoice = preload_invoice_entity(invoice)
    story = Repo.preload(invoice.story, [:developer])
    invoice_items_map = InvoiceItem.get_active_invoice_items(invoice)
    base_total_invoice_amount = get_total_invoice_amount(invoice_items_map)
    bank_account = BankAccount.create_bank_account_map(invoice.billing_company.bank_account)
    has_gst = not is_nil(invoice.billing_company.gst)

    organization_map =
      Organization
      |> join(:inner, [o], c in Credential, on: c.organization_id == o.id)
      |> where([o, c], c.broker_id == ^invoice.broker.id and c.active == true)
      |> select([o, c], %{"name" => o.name, "gst" => o.gst_number, "rera_id" => o.rera_id, "phone_number" => c.phone_number})
      |> Repo.one()

    %{
      "cgst" => if(has_gst, do: (base_total_invoice_amount * 0.09) |> ceil(), else: nil),
      "sgst" => if(has_gst, do: (base_total_invoice_amount * 0.09) |> ceil(), else: nil),
      "tds" => if(has_gst, do: (base_total_invoice_amount * 0.01) |> ceil(), else: nil),
      "tcs" => if(has_gst, do: (base_total_invoice_amount * 0.01) |> ceil(), else: nil),
      "has_gst" => has_gst,
      "total_invoice_amount" => if(has_gst, do: base_total_invoice_amount * 1.16, else: base_total_invoice_amount * 0.99) |> ceil(),
      "invoice_amount" => base_total_invoice_amount,
      "invoice_pdf_url" => invoice.invoice_pdf_url,
      "invoice_number" => invoice.invoice_number,
      "invoice_date" => invoice.invoice_date,
      "developer_name" => invoice.legal_entity.legal_entity_name,
      "project_name" => story.name,
      "legal_entity_name" => invoice.legal_entity.legal_entity_name,
      "broker_name" => invoice.broker.name,
      "bank" => bank_account,
      "invoice_items" => invoice_items_map,
      "invoice_uuid" => invoice.uuid,
      "status" => invoice.status,
      "invoice_approvals" => invoice_approvals_map(invoice),
      "org" => organization_map |> Map.drop(["phone_number"]),
      "phone_number" => organization_map["phone_number"],
      "show_change_requested" => is_nil(invoice.booking_rewards_lead_id)
    }
  end

  def get_all_poc_phone_number(invoice_id) do
    Invoice
    |> join(:inner, [i], l in assoc(i, :legal_entity))
    |> join(:inner, [i, l], poc in assoc(l, :legal_entity_pocs))
    |> where([i], i.id == ^invoice_id)
    |> select([i, l, poc], poc.phone_number)
    |> Repo.all()
  end

  def broadcast_to_poc_whatsapp(invoice = %Invoice{type: type}) when type in @broker_invoice_types do
    sub_query = from(item in BnApis.Stories.Schema.InvoiceItem, where: item.active == true)
    invoice = Repo.preload(invoice, [:legal_entity, :billing_company, broker: [credentials: [:organization]], invoice_items: sub_query])
    [invoice_items | _] = invoice.invoice_items
    cred = Enum.find(invoice.broker.credentials, fn cred -> cred.active == true end)

    vars = [
      Timex.format!(invoice.updated_at, "{0D}-{0M}-{YYYY}"),
      invoice.legal_entity.legal_entity_name,
      "*#{get_invoice_value_after_tax(invoice)}*",
      invoice.broker.name,
      cred.organization.name,
      cred.phone_number,
      invoice_items.customer_name
    ]

    get_all_poc_phone_number(invoice.id)
    |> Enum.each(fn number ->
      Exq.enqueue(Exq, "send_sms", BnApis.Whatsapp.SendWhatsappMessageWorker, [number, "invoice_new_1", vars])
    end)
  end

  def broadcast_to_poc_whatsapp(_invoice), do: :ok

  def broadcast_to_poc_whatsapp(invoice = %Invoice{type: type}, poc_approval) when type in @broker_invoice_types do
    sub_query = from item in BnApis.Stories.Schema.InvoiceItem, where: item.active == true
    invoice = Repo.preload(invoice, [:billing_company, invoice_items: sub_query])
    poc_approval = Repo.preload(poc_approval, [:legal_entity_poc])

    template = if poc_approval.action == :approved, do: "invoice_3", else: "invoice_2"

    approved_at = Time.epoch_to_naive(poc_approval.approved_at * 1000) |> Timex.Timezone.convert("Asia/Kolkata") |> Timex.format!("{0D}-{0M}-{YYYY}")

    vars = [
      "*#{invoice.invoice_number}*",
      "*#{get_invoice_value_after_tax(invoice)}*",
      "*#{poc_approval.legal_entity_poc.poc_name}*",
      "*#{poc_approval.legal_entity_poc.phone_number}*",
      "*#{approved_at}*"
    ]

    get_all_poc_phone_number(invoice.id)
    |> Enum.each(fn number ->
      Exq.enqueue(Exq, "send_sms", BnApis.Whatsapp.SendWhatsappMessageWorker, [number, template, vars, %{"entity_type" => "poc_invoice_approvals", "entity_id" => poc_approval.id}])
    end)

    :ok
  end

  defp send_new_invoice_created_notification(cred) do
    notif_data = %{
      "data" => %{
        "title" => "New Invoice Created",
        "message" => "Please review the invoice for further processing",
        "intent" => "com.dialectic.brokernetworkapp.actions.PROJECT.INVOICE"
      },
      "type" => "GENERIC_NOTIFICATION"
    }

    Exq.enqueue(Exq, "send_new_invoice_notification", BnApis.Notifications.PushNotificationWorker, [
      cred.fcm_id,
      notif_data,
      cred.id,
      cred.notification_platform
    ])
  end

  defp filter_by_search_text(query, nil), do: query

  defp filter_by_search_text(query, search_text) do
    search_text = search_text |> String.trim()
    search_text = search_text <> "%"

    query
    |> where([inv, br], ilike(br.name, ^search_text))
  end

  def mark_as_approved_by_org_admin(uuid, user_map, 1, 1) do
    with %Invoice{is_created_by_piramal: false, type: type} = invoice when type in ["brokerage", "booking_reward"] <- get_invoice_by_uuid(uuid) do
      invoice
      |> Invoice.changeset(%{status: "approval_pending"})
      |> AuditedRepo.update(user_map)
    else
      nil -> {:error, "Invoice not found."}
      %Invoice{is_created_by_piramal: true} -> {:error, "Invoice created by Piramal are already pre-approved."}
      %Invoice{type: "dsa"} -> {:error, "This operation is not allowed on DSA invoice"}
    end
  end

  def mark_as_approved_by_org_admin(_uuid, _user_map, _broker_role_id, _role_type_id), do: {:error, "Not allowed to approve invoice"}

  def mark_as_rejected_by_org_admin(uuid, rejection_reason, user_map, 1, 1) do
    with %Invoice{is_created_by_piramal: false, type: type} = invoice when type in ["brokerage", "booking_reward"] <- get_invoice_by_uuid(uuid) do
      invoice
      |> Invoice.changeset(%{status: "rejected_by_admin", change_notes: rejection_reason})
      |> AuditedRepo.update(user_map)
    else
      nil -> {:error, "Invoice not found."}
      %Invoice{is_created_by_piramal: true} -> {:error, "This operation is not allowed for invoices created by Piramal."}
      %Invoice{type: "dsa"} -> {:error, "This operation is not allowed on DSA invoice"}
    end
  end

  def mark_as_rejected_by_org_admin(_uuid, _rejection_reason, _user_map, _broker_role_id, _role_type_id), do: {:error, "Not allowed to reject invoice."}

  defp get_invoice_value_after_tax(invoice) do
    total_invoice_amount = get_total_invoice_amount(invoice.invoice_items)
    has_gst = not is_nil(invoice.billing_company.gst)
    if(has_gst, do: total_invoice_amount * 1.16, else: total_invoice_amount * 0.99) |> ceil()
  end

  def auto_approve_by_bn_bots(invoice, user_map) do
    LegalEntityPoc.auto_approve_bots()
    |> Enum.reduce(true, fn poc, acc ->
      PocApprovals.new(%{role_type: poc.poc_type, action: "approved", legal_entity_poc_id: poc.id, invoice_id: invoice.id, approved_at: DateTime.to_unix(DateTime.utc_now())})
      |> AuditedRepo.insert(user_map)
      |> case do
        {:ok, _poc_approval} -> true or acc
        {:error, reason} -> Repo.rollback(reason)
      end
    end)
  end

  def migrate_approval_for_booking_rewards(poc_approvals, invoice, user_map) do
    Enum.reduce(poc_approvals, true, fn action, acc ->
      PocApprovals.new(%{
        role_type: action.role_type,
        action: action.action,
        legal_entity_poc_id: action.legal_entity_poc_id,
        invoice_id: invoice.id,
        approved_at: action.approved_at
      })
      |> AuditedRepo.insert(user_map)
      |> case do
        {:ok, _poc_approval} -> true or acc
        {:error, reason} -> Repo.rollback(reason)
      end
    end)
  end

  def get_invoice_logs(invoice_id, page_no) do
    logs = Log.get_logs(invoice_id, "invoices", page_no)
    {:ok, logs}
  end
end
