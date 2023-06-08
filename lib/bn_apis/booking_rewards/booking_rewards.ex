defmodule BnApis.BookingRewards do
  use Ecto.Schema
  import Ecto.Query
  alias BnApis.Repo
  alias BnApis.Helpers.AuditedRepo
  alias BnApis.Stories.Story
  alias BnApis.Organizations.Broker
  alias BnApis.Stories.LegalEntity
  alias BnApis.Stories.LegalEntityPocMapping
  alias BnApis.BookingRewards.Schema.{BookingRewardsLead, BookingClient, BookingPayment}

  alias BnApis.Helpers.Time
  alias BnApis.Helpers.S3Helper
  alias BnApis.Helpers.Utils
  alias BnApis.Stories.BookingInvoice
  alias BnApis.Helpers.InvoiceHelper
  alias BnApis.Schemas.LegalEntityPoc
  alias BnApis.Stories.Schema.Invoice, as: InvoiceSchema
  alias BnApis.Stories.Invoice
  alias BnApis.BookingRewards.{Status, BookingRewardsHelper}
  alias BnApis.Stories.Schema.PocApprovals

  @claim_reward_msg "Yay! Reward of 10,000 is waiting for you. Add details to claim the reward."

  @booking_reward_invoice_type InvoiceSchema.type_reward()
  @brokerage_invoice_type InvoiceSchema.type_brokerage()

  @booking_reward_amount 10000

  @pending_status_id Status.get_status_id!("pending")
  @change_requested_status_id Status.get_status_id!("changes_requested")
  @approved_by_bn_status_id Status.get_status_id!("approved_by_bn")
  @approved_by_crm_status_id Status.get_status_id!("approved_by_crm")
  @approved_by_finance_status_id Status.get_status_id!("approved_by_finance")
  @paid_status_id Status.get_status_id!("paid")
  @rejected_by_bn_status_id Status.get_status_id!("rejected_by_bn")
  @rejected_by_crm_status_id Status.get_status_id!("rejected_by_crm")
  @rejected_by_finance_status_id Status.get_status_id!("rejected_by_finance")
  @expired_status_id Status.get_status_id!("expired")

  @legal_entity_poc_type_finance LegalEntityPoc.poc_type_finance()

  @pending_poc_br_flag "pending"
  @approved_poc_br_flag "approved"

  def create(params = %{"unit_details" => unit_details, "status" => status}, logged_in_user) do
    if status == "pending" do
      broker_id = logged_in_user[:broker_id]
      user_map = Utils.get_user_map(logged_in_user)
      booking_rewards_lead_params = create_params_map(unit_details, broker_id, params["booking_client"], params["booking_payment"], status)

      %{"old_broker_id" => broker_id, "old_organization_id" => logged_in_user[:organization_id]}
      |> Map.merge(booking_rewards_lead_params)
      |> BookingRewardsLead.create(user_map)
    else
      {:error, "Status value: #{status} not allowed while creation."}
    end
  end

  def update(params = %{"uuid" => uuid, "unit_details" => unit_details}, logged_in_user) do
    broker_id = logged_in_user[:broker_id]
    user_map = Utils.get_user_map(logged_in_user)

    case BookingRewardsLead.get_by_uuid(uuid) do
      nil ->
        nil

      booking_rewards_lead ->
        if booking_rewards_lead.status_id in [@pending_status_id, @change_requested_status_id] do
          booking_rewards_lead =
            booking_rewards_lead
            |> Repo.preload([:booking_client, :booking_payment])

          status = Status.get_status_from_id(@pending_status_id)

          booking_rewards_lead_params = create_params_map(unit_details, broker_id, params["booking_client"], params["booking_payment"], status)

          booking_rewards_lead_params = Map.put(booking_rewards_lead_params, "booking_rewards_pdf", nil)
          S3Helper.async_delete_file(booking_rewards_lead.booking_rewards_pdf)
          BookingRewardsLead.update(booking_rewards_lead, booking_rewards_lead_params, user_map)
        else
          {:error, "This booking rewards lead can not be updated. Status: #{Status.get_status_from_id(booking_rewards_lead.status_id)}"}
        end
    end
  end

  def delete(uuid, logged_in_user) do
    user_map = Utils.get_user_map(logged_in_user)

    with %BookingRewardsLead{} = lead <- BookingRewardsLead.get_by_uuid(uuid),
         {:ok, _} <- BookingRewardsLead.update(lead, %{"deleted" => true}, user_map) do
      :ok
    else
      nil -> {:error, "No entry for given uuid"}
      {:error, _changeset} = error -> error
    end
  end

  def fetch_booking_rewards_lead(uuid) do
    case BookingRewardsLead.get_by_uuid(uuid) do
      nil ->
        nil

      brl ->
        brl
        |> Repo.preload([
          :booking_client,
          :booking_payment,
          [story: :developer],
          :broker,
          :legal_entity,
          [billing_company: :bank_account]
        ])
    end
  end

  def update_invoice_details(
        params = %{
          "uuid" => uuid,
          "invoice_number" => _invoice_number,
          "invoice_date" => _invoice_date,
          "billing_company_id" => _billing_company_id
        },
        logged_in_user
      ) do
    user_map = Utils.get_user_map(logged_in_user)

    case BookingRewardsLead.get_by_uuid(uuid) do
      nil ->
        nil

      %BookingRewardsLead{status_id: @approved_by_crm_status_id} = booking_rewards_lead ->
        params = Map.take(params, ~w(invoice_number invoice_date billing_company_id))

        Repo.transaction(fn ->
          with {:ok, lead} <- BookingRewardsLead.update(booking_rewards_lead, params, user_map),
               :ok <- Repo.preload(lead, [:invoices]) |> create_booking_reward_invoice(user_map) do
            lead
          else
            {:error, reason} -> Repo.rollback(reason)
          end
        end)

      booking_rewards_lead ->
        {:error, "Can't update invoice details due to status: #{Status.get_status_from_id(booking_rewards_lead.status_id)}"}
    end
  end

  defp create_params_map(unit_details, broker_id, booking_client, booking_payment, status) do
    params_map =
      unit_details
      |> Map.put("broker_id", broker_id)
      |> Map.put("status_id", Status.get_status_id!(status))

    params_map = if not is_nil(booking_client) and booking_client != %{}, do: Map.put(params_map, "booking_client", booking_client), else: params_map

    if not is_nil(booking_payment) and booking_payment != %{}, do: Map.put(params_map, "booking_payment", booking_payment), else: params_map
  end

  def maybe_update_status_to_paid(lead, user_map, type) when type == @booking_reward_invoice_type do
    BookingRewardsLead.changeset(lead, %{status_id: @paid_status_id})
    |> AuditedRepo.update(user_map)
  end

  def maybe_update_status_to_paid(_lead, _user_map, _type), do: {:ok, nil}

  def get_brokers_booking_rewards_leads(params, logged_in_user) do
    broker_id = logged_in_user[:broker_id]
    status_ids = get_status_ids(params["status_ids"])
    page_no = (params["p"] || "1") |> String.to_integer()
    {:ok, get_paginated_booking_rewards_lead(broker_id, status_ids, page_no)}
  end

  def get_paginated_booking_rewards_lead(broker_id, status_ids, page_no) do
    limit = 30
    offset = (page_no - 1) * limit

    results =
      BookingRewardsLead
      |> where([brl], brl.broker_id == ^broker_id and brl.deleted == false)
      |> filter_by_status_ids(status_ids)
      |> preload([:booking_client, :booking_payment, :broker, invoices: [:booking_invoice], story: [:polygon]])
      |> offset(^offset)
      |> limit(^(limit + 1))
      |> order_by([brl], desc: brl.inserted_at)
      |> Repo.all()
      |> create_booking_rewards_leads_map()

    %{
      "results" => Enum.slice(results, 0, limit),
      "has_more_page" => length(results) > limit,
      "filters" => Status.get_status_filter_list(status_ids),
      "claim_msg" => @claim_reward_msg
    }
  end

  def filter_by_status_ids(query, []), do: query

  def filter_by_status_ids(query, status_ids) do
    query
    |> where([brl], brl.status_id in ^status_ids)
  end

  def get_status_ids(nil), do: []

  def get_status_ids(status_ids) do
    status_ids
    |> String.split(",")
    |> Enum.reject(&(&1 == ""))
    |> Enum.map(&String.to_integer(String.trim(&1)))
  end

  def create_booking_rewards_leads_map(booking_rewards_leads) do
    booking_rewards_leads
    |> Enum.map(fn brl ->
      reward_amount = get_reward_amount(brl)
      raise_invoice_flag = should_raise_invoice?(brl)

      %{
        "id" => brl.id,
        "uuid" => brl.uuid,
        "broker_name" => brl.broker.name,
        "project" => brl.story.name,
        "updated_at" => brl.updated_at |> Timex.to_datetime() |> DateTime.to_unix(),
        "latest_status" => get_latest_status(brl.status_id),
        "latest_status_for_dev_eco" => Status.get_status_from_id(brl.status_id),
        "polygon" => if(is_nil(brl.story.polygon), do: nil, else: brl.story.polygon.name),
        "booking_client_name" => if(is_nil(brl.booking_client), do: nil, else: brl.booking_client.name),
        "token_amount" => if(is_nil(brl.booking_payment), do: nil, else: brl.booking_payment.token_amount),
        "payment_mode" => if(is_nil(brl.booking_payment), do: nil, else: brl.booking_payment.payment_mode),
        "claim_reward_enabled" => should_claim_reward?(brl),
        "raise_invoice_enabled" => raise_invoice_flag,
        "status_message" => brl.status_message,
        "reward_amount" => reward_amount,
        "reward_status_message" => get_reward_status_message(reward_amount, brl, raise_invoice_flag)
      }
    end)
  end

  def get_latest_status(@approved_by_crm_status_id), do: "approved"
  def get_latest_status(status_id) when status_id in [@approved_by_bn_status_id, @approved_by_finance_status_id], do: "pending"
  def get_latest_status(status_id) when status_id in [@rejected_by_bn_status_id, @rejected_by_finance_status_id, @rejected_by_crm_status_id], do: "rejected"
  def get_latest_status(status_id), do: Status.get_status_from_id(status_id)

  def fetch_booking_reward_by_status(status_string, page, limit, phone_number, project_name, developer_name) do
    offset = (page - 1) * limit

    BookingRewardsLead
    |> filter_by_status(status_string)
    |> filter_by_broker(phone_number)
    |> filter_by_project(project_name)
    |> filter_by_developer(developer_name)
    |> order_by(desc: :updated_at)
    |> limit(^limit)
    |> offset(^offset)
    |> preload([:booking_client, :booking_payment, :broker, :legal_entity, :invoices, poc_approvals: [:legal_entity_poc], story: [:developer]])
    |> Repo.all()
    |> Enum.map(&booking_reward_to_map/1)
  end

  def get_booking_map_from_uuid(uuid) do
    case BookingRewardsLead.get_by_uuid(uuid, [
           :broker,
           :story,
           :legal_entity,
           :invoices,
           :booking_payment,
           :booking_client
         ]) do
      nil -> {:error, "invalid uuid"}
      lead -> {:ok, booking_reward_to_map(lead)}
    end
  end

  def booking_reward_to_map(booking_rewards_lead) do
    broker_map = Broker.create_broker_map(booking_rewards_lead.broker)
    story_map = Story.create_story_map(booking_rewards_lead.story)
    legal_entity = legal_entity_map(booking_rewards_lead.legal_entity)

    poc_approvals =
      if Ecto.assoc_loaded?(booking_rewards_lead.poc_approvals) do
        Enum.map(booking_rewards_lead.poc_approvals, fn action ->
          %{
            "id" => action.legal_entity_poc.id,
            "name" => action.legal_entity_poc.poc_name,
            "approved_at" => action.approved_at,
            "role_type" => action.role_type,
            "action" => action.action
          }
        end)
      end

    %{
      uuid: booking_rewards_lead.uuid,
      legal_entity: legal_entity,
      broker: broker_map,
      story: story_map,
      unit_details: %{
        booking_date: booking_rewards_lead.booking_date,
        booking_form_number: booking_rewards_lead.booking_form_number,
        rera_number: booking_rewards_lead.rera_number,
        unit_number: booking_rewards_lead.unit_number,
        rera_carpet_area: booking_rewards_lead.rera_carpet_area,
        building_name: booking_rewards_lead.building_name,
        wing: booking_rewards_lead.wing,
        agreement_value: booking_rewards_lead.agreement_value,
        agreement_proof: S3Helper.get_imgix_url(booking_rewards_lead.agreement_proof),
        story_id: booking_rewards_lead.story_id,
        story_name: booking_rewards_lead.story.name,
        broker_id: booking_rewards_lead.broker_id,
        broker_name: booking_rewards_lead.broker.name
      },
      invoice_number: booking_rewards_lead.invoice_number,
      invoice_date: booking_rewards_lead.invoice_date,
      status: get_latest_status(booking_rewards_lead.status_id),
      status_for_dev_eco: Status.get_status_from_id(booking_rewards_lead.status_id),
      client: BookingClient.to_map(booking_rewards_lead.booking_client),
      booking_payment: BookingPayment.to_map(booking_rewards_lead.booking_payment),
      created_at: booking_rewards_lead.inserted_at,
      approved_at: booking_rewards_lead.approved_at,
      status_message: booking_rewards_lead.status_message,
      developer_response_pdf: booking_rewards_lead.developer_response_pdf,
      booking_rewards_pdf: booking_rewards_lead.booking_rewards_pdf,
      reference_invoices: Enum.map(booking_rewards_lead.invoices, &Map.take(&1, ~w(uuid type)a)),
      poc_approvals: poc_approvals
    }
  end

  def upload_pdf_and_approve(file, uuid, user_map) do
    case BookingRewardsLead.get_by_uuid(uuid) do
      nil ->
        nil

      %BookingRewardsLead{status_id: status_id} when status_id in [@rejected_by_bn_status_id, @rejected_by_finance_status_id, @rejected_by_crm_status_id] ->
        {:error, "cannot go from status `rejected` to `approved`"}

      lead ->
        lead
        |> BookingRewardsLead.changeset(%{
          developer_response_pdf: file,
          status_id: @approved_by_bn_status_id,
          approved_at: NaiveDateTime.utc_now()
        })
        |> AuditedRepo.update(user_map)
        |> case do
          {:ok, lead} ->
            broadcast_whatsapp(lead)
            {:ok, lead}

          error ->
            error
        end
    end
  end

  def mark_as_approved_by_bn(uuid, user_map) do
    case BookingRewardsLead.get_by_uuid(uuid, [:booking_payment, :booking_client]) do
      nil ->
        nil

      %BookingRewardsLead{status_id: status_id} when status_id in [@rejected_by_bn_status_id, @rejected_by_finance_status_id, @rejected_by_crm_status_id] ->
        {:error, "cannot go from status `rejected` to `approved`"}

      lead ->
        lead
        |> BookingRewardsLead.changeset(%{
          status_id: @approved_by_bn_status_id,
          approved_at: NaiveDateTime.utc_now()
        })
        |> AuditedRepo.update(user_map)
        |> case do
          {:ok, lead} ->
            broadcast_whatsapp(lead)
            {:ok, lead}

          error ->
            error
        end
    end
  end

  def update_br_status_by_poc(poc_id, br_uuid, status, user_map, action, change_notes \\ nil) do
    changes = %{status_id: get_status_id(status)}
    changes = if not is_nil(change_notes), do: Map.put(changes, :status_message, change_notes), else: changes

    with %LegalEntityPoc{active: true} = poc <- LegalEntityPoc.get_by_id(poc_id),
         %BookingRewardsLead{} = br <- BookingRewardsLead.get_by_uuid(br_uuid, [:booking_payment, :booking_client]) do
      Repo.transaction(fn ->
        with {:ok, reward_lead} <- BookingRewardsLead.changeset(br, changes) |> AuditedRepo.update(user_map),
             {:ok, poc_approvals} <-
               PocApprovals.new(%{
                 role_type: poc.poc_type,
                 action: action,
                 legal_entity_poc_id: poc_id,
                 booking_rewards_lead_id: reward_lead.id,
                 approved_at: DateTime.to_unix(DateTime.utc_now())
               })
               |> AuditedRepo.insert(user_map) do
          if action in ~w(approved rejected) do
            broadcast_whatsapp(reward_lead, poc_approvals)
          end

          reward_lead
        else
          {:error, reason} -> Repo.rollback(reason)
        end
      end)
    else
      nil -> {:error, :not_found}
      %LegalEntityPoc{} -> {:error, "You have been deactivated"}
    end
  end

  defp get_status_id(status) do
    case status do
      "approved_by_finance" -> @approved_by_finance_status_id
      "approved_by_crm" -> @approved_by_crm_status_id
      "rejected_by_finance" -> @rejected_by_finance_status_id
      "rejected_by_crm" -> @rejected_by_crm_status_id
      "change" -> @change_requested_status_id
    end
  end

  def update_booking_form(attrs, user_map) do
    with %BookingRewardsLead{} = lead <- BookingRewardsLead.get_by_uuid(attrs["uuid"], broker: :credentials),
         {:ok, params} <- validate_status_change_sanitize_params(attrs["status"], lead.status_id, attrs) do
      changeset = BookingRewardsLead.changeset(lead, params)

      AuditedRepo.update(changeset, user_map)
      |> case do
        {:ok, data} ->
          maybe_send_changes_requested_fcm_notification(attrs["status"], lead, attrs["message"])
          {:ok, data}

        {:error, reason} ->
          {:error, reason}
      end
    end
  end

  def create_booking_reward_invoice(%BookingRewardsLead{} = lead, user_map) do
    with true <- should_claim_reward?(lead),
         true <- invoice_details_filled?(lead),
         {:ok, invoice} <- create_invoice(lead, user_map),
         {:ok, _} <- create_booking_reward_invoice_pdf(invoice, user_map) do
      :ok
    else
      false -> {:error, "Status not `approved` or invoice already exist or invoice details do not exist"}
      {:error, _reason} = error -> error
    end
  end

  def create_booking_reward_invoice_pdf(invoice, user_map) do
    has_gst? = not is_nil(invoice.billing_company.gst)

    path =
      invoice
      |> BookingInvoice.create_booking_invoice_pdf_params(has_gst?, invoice.bonus_amount, invoice.id)
      |> put_items_in_invoice()
      |> InvoiceHelper.get_path_for_booking_invoice(has_gst?)

    "booking_rewards_invoices"
    |> InvoiceHelper.upload_invoice(path, invoice.id)
    |> InvoiceHelper.get_pdf_url()
    |> case do
      nil ->
        {:error, "Something went wrong file generating invoice PDF."}

      url ->
        InvoiceSchema.changeset(invoice, %{invoice_pdf_url: url})
        |> AuditedRepo.update(user_map)
        |> case do
          {:ok, _} -> {:ok, url}
          error -> error
        end
    end
  end

  def put_items_in_invoice(invoice) do
    lead = Repo.preload(invoice.booking_rewards_lead, [:booking_client])

    item = %{
      customer_name: lead.booking_client.name,
      unit_number: lead.unit_number,
      wing_name: lead.wing,
      building_name: lead.building_name,
      agreement_value: lead.agreement_value,
      brokerage_amount: 0
    }

    Map.put(invoice, :invoice_items, [item])
  end

  def generate_booking_reward_pdf(uuid, user_map) do
    case BookingRewardsLead.get_by_uuid(uuid) do
      nil ->
        {:error, "booking reward does not exist"}

      booking_rewards_lead ->
        booking_rewards_lead
        |> Repo.preload([:broker, :booking_client, :booking_payment, :legal_entity, [story: :polygon]])
        |> BookingRewardsHelper.create_map_for_pdf()
        |> BookingRewardsHelper.generate_booking_reward_pdf(booking_rewards_lead, user_map)
    end
  end

  defp filter_by_broker(query, phone_number) when is_bitstring(phone_number) do
    query
    |> join(:left, [b], br in assoc(b, :broker))
    |> join(:left, [b, br], cred in assoc(br, :credentials))
    |> where([b, br, cred], cred.phone_number == ^phone_number)
  end

  defp filter_by_broker(query, _phone_number), do: query

  defp filter_by_project(query, project_name) when is_bitstring(project_name) do
    project_name = "%" <> project_name <> "%"

    query
    |> join(:left, [b], s in assoc(b, :story))
    |> where([b, ..., s], ilike(s.name, ^project_name))
  end

  defp filter_by_project(query, _project_name), do: query

  defp filter_by_developer(query, developer_name) when is_bitstring(developer_name) do
    developer_name = "%" <> developer_name <> "%"

    query
    |> join(:left, [b], s in assoc(b, :story))
    |> join(:left, [b, ..., s], d in assoc(s, :developer))
    |> where([b, ..., d], ilike(d.name, ^developer_name))
  end

  defp filter_by_developer(query, _developer_name), do: query

  def create_invoice(lead, user_map) do
    params = %{
      "status" => "approved_by_crm",
      "invoice_number" => lead.invoice_number,
      "invoice_date" => lead.invoice_date,
      "legal_entity_id" => lead.legal_entity_id,
      "billing_company_id" => lead.billing_company_id,
      "entity_id" => lead.story_id,
      "type" => InvoiceSchema.type_reward(),
      "bonus_amount" => @booking_reward_amount,
      "broker_id" => lead.broker_id,
      "booking_rewards_lead_id" => lead.id,
      "entity_type" => "stories",
      "old_broker_id" => lead.broker_id,
      "old_organization_id" => lead.old_organization_id
    }

    lead = Repo.preload(lead, [:poc_approvals])
    approvals = Enum.reduce(lead.poc_approvals, 0, fn poc_action, acc -> if poc_action.action == :approved, do: acc + 1, else: acc end)

    Repo.transaction(fn ->
      with {:valid_size, true} <- {:valid_size, approvals >= 2},
           {:ok, invoice} <- %InvoiceSchema{} |> InvoiceSchema.changeset(params) |> AuditedRepo.insert(user_map),
           true <- Invoice.migrate_approval_for_booking_rewards(lead.poc_approvals, invoice, user_map) do
        Repo.preload(invoice, billing_company: [:bank_account]) |> Map.put(:booking_rewards_lead, lead)
      else
        {:error, reason} -> Repo.rollback(reason)
        {:valid_size, false} -> Repo.rollback("Need approval from 2 people")
        true -> Repo.rollback("Unable to update poc approval")
      end
    end)
  end

  defp validate_status_change_sanitize_params(nil, _old_status_id, params),
    do: {:ok, Map.take(params, ~w(invoice_number invoice_date))}

  defp validate_status_change_sanitize_params(status, old_status_id, params) do
    new_status_id = Status.get_status_id!(status)

    cond do
      new_status_id in [@approved_by_bn_status_id, @approved_by_finance_status_id, @approved_by_crm_status_id] -> {:error, "cannot set status to `approved` from this api"}
      new_status_id >= old_status_id -> {:ok, %{status_id: new_status_id, status_message: params["message"]}}
      true -> {:error, "Cannot no back to previous status"}
    end
  end

  defp should_claim_reward?(brl) do
    booking_reward_invoice_exists = not is_nil(Enum.find(brl.invoices, fn iv -> iv.type == @booking_reward_invoice_type end))

    brl.status_id == @approved_by_crm_status_id and not booking_reward_invoice_exists
  end

  defp should_raise_invoice?(brl) do
    brokerage_invoice = Enum.find(brl.invoices, fn iv -> iv.type == @brokerage_invoice_type end)

    brl.status_id in [@paid_status_id, @expired_status_id] and invoice_details_filled?(brl) and
      is_nil(brokerage_invoice)
  end

  defp invoice_details_filled?(brl) do
    nil not in [brl.invoice_date, brl.invoice_number, brl.billing_company_id]
  end

  defp legal_entity_map(legal_entity) do
    legal_entity_map = LegalEntity.create_legal_entity_map(legal_entity)

    if legal_entity_map do
      legal_entity_pocs = LegalEntityPocMapping.get_legal_entity_pocs_for_legal_entity(Map.get(legal_entity_map, "id"))
      Map.put(legal_entity_map, :legal_entity_pocs, legal_entity_pocs)
    else
      legal_entity_map
    end
  end

  defp filter_by_status(query, "all") do
    where(query, [b], b.status_id in ^Status.ids() and b.deleted == false)
  end

  defp filter_by_status(query, "approved") do
    query
    |> where([b], b.status_id in [@approved_by_crm_status_id, @approved_by_finance_status_id, @approved_by_bn_status_id] and b.deleted == false)
  end

  defp filter_by_status(query, "rejected") do
    query
    |> where([b], b.status_id in [@rejected_by_crm_status_id, @rejected_by_finance_status_id, @rejected_by_bn_status_id] and b.deleted == false)
  end

  defp filter_by_status(query, status) do
    where(query, status_id: ^Status.get_status_id!(status), deleted: false)
  end

  defp get_reward_amount(brl) do
    if brl.status_id in [@paid_status_id, @expired_status_id] do
      case Enum.find(brl.invoices, fn inv -> inv.type == @booking_reward_invoice_type end) do
        nil ->
          nil

        _inv ->
          case Enum.find(brl.invoices, fn inv ->
                 inv.type == @brokerage_invoice_type and not is_nil(inv.booking_invoice) and inv.status == "paid"
               end) do
            nil -> 10000
            _ -> 20000
          end
      end
    else
      nil
    end
  end

  defp get_reward_status_message(10000 = _reward_amount, brl, true = _raise_invoice_flag) do
    cond do
      brl.status_id == @paid_status_id -> "Yay! Reward of ₹10,000 is waiting for you."
      brl.status_id == @expired_status_id -> "Reward of ₹10,000 expired."
    end
  end

  defp get_reward_status_message(10000 = _reward_amount, brl, false = _raise_invoice_flag) do
    brokerage_invoice = Enum.find(brl.invoices, fn inv -> inv.type == @brokerage_invoice_type end)

    cond do
      brokerage_invoice.status == "approved" -> "Processing your reward of ₹10,000."
      brokerage_invoice.status == "approval_pending" -> "Waiting for approval on your reward of ₹10,000."
      brokerage_invoice.status == "rejected" -> "Reward of ₹10,000 rejected."
      true -> nil
    end
  end

  defp get_reward_status_message(_reward_amount, _brl, _raise_invoice_flag), do: nil

  defp maybe_send_changes_requested_fcm_notification("changes_requested", lead, message) do
    cred = Utils.get_active_fcm_credential(lead.broker.credentials)
    send_fcm_notification(cred, lead, message)
  end

  defp maybe_send_changes_requested_fcm_notification(_, _lead, _message), do: :ok

  defp send_fcm_notification(nil, _lead, _message), do: nil

  defp send_fcm_notification(cred, lead, message) do
    data = %{
      type: "BOOKING_REWARD_CHANGE_REQUESTED",
      data: %{
        booking_uuid: lead.uuid,
        title: "Booking Form Change Requested",
        message: message
      }
    }

    Exq.enqueue(Exq, "send_changes_requested_fcm_notification", BnApis.Notifications.PushNotificationWorker, [
      cred.fcm_id,
      data,
      cred.id,
      cred.notification_platform
    ])
  end

  def fetch_booking_reward_leads_for_le_poc(poc_id, @approved_poc_br_flag, page, limit, _role_type) do
    offset = (page - 1) * limit
    approval = from(a in PocApprovals, order_by: [desc: a.inserted_at])

    BookingRewardsLead
    |> join(:inner, [brl], ap in assoc(brl, :poc_approvals))
    |> where([brl, ap], ap.legal_entity_poc_id == ^poc_id)
    |> group_by([b], b.id)
    |> order_by(desc: :updated_at)
    |> limit(^limit)
    |> offset(^offset)
    |> preload([
      :booking_client,
      :booking_payment,
      :legal_entity,
      :invoices,
      story: [:developer],
      poc_approvals: ^{approval, [:legal_entity_poc]},
      broker: [credentials: [:organization]]
    ])
    |> Repo.all()
    |> Enum.map(&booking_reward_to_map_poc/1)
  end

  def fetch_booking_reward_leads_for_le_poc(poc_id, @pending_poc_br_flag, page, limit, role_type) do
    offset = (page - 1) * limit

    status_id = if role_type == @legal_entity_poc_type_finance, do: @approved_by_bn_status_id, else: @approved_by_finance_status_id

    BookingRewardsLead
    |> join(:inner, [brl], le in LegalEntity, on: le.id == brl.legal_entity_id)
    |> join(:inner, [brl, le], m in LegalEntityPocMapping, on: m.legal_entity_id == le.id)
    |> join(:inner, [brl, le, m], le_poc in LegalEntityPoc, on: m.legal_entity_poc_id == le_poc.id)
    |> join(:left, [brl], b in assoc(brl, :broker))
    |> join(:left, [brl, ..., b], cred in assoc(b, :credentials))
    |> where(
      [brl, le, m, le_poc, ..., cred],
      le_poc.active == true and m.active == true and le_poc.id == ^poc_id and brl.status_id == ^status_id and cred.active == true
    )
    |> order_by(desc: :updated_at)
    |> limit(^limit)
    |> offset(^offset)
    |> preload([:booking_client, :booking_payment, :legal_entity, :invoices, story: [:developer], broker: [credentials: [:organization]]])
    |> Repo.all()
    |> Enum.map(&booking_reward_to_map_poc/1)
  end

  defp booking_reward_to_map_poc(booking_rewards_lead) do
    [cred | _] = booking_rewards_lead.broker.credentials

    booking_reward_to_map(booking_rewards_lead)
    |> Map.put(:org, %{name: cred.organization.name, gst: cred.organization.gst_number, rera_id: cred.organization.rera_id})
  end

  def broadcast_whatsapp(reward_lead) do
    approved_at = reward_lead.inserted_at |> Timex.Timezone.convert("Asia/Kolkata") |> Timex.format!("{0D}-{0M}-{YYYY}")
    reward_lead = Repo.preload(reward_lead, [:booking_client, broker: [credentials: :organization]])
    cred = Enum.find(reward_lead.broker.credentials, fn cred -> cred.active == true end)

    vars = [
      "*#{approved_at}*",
      "*#{reward_lead.broker.name}*",
      "*#{cred.organization.name}*",
      "*#{cred.phone_number}*",
      "*#{reward_lead.booking_client.name}*",
      "*#{reward_lead.unit_number}*",
      "*#{reward_lead.wing}*",
      "*#{reward_lead.building_name}*"
    ]

    send_to_poc_phone_numbers("booking_new_1", vars, reward_lead.id)
  end

  def broadcast_whatsapp(reward_lead, poc_approvals) do
    poc_approvals = Repo.preload(poc_approvals, [:legal_entity_poc])
    approved_at = Time.epoch_to_naive(poc_approvals.approved_at * 1000) |> Timex.Timezone.convert("Asia/Kolkata") |> Timex.format!("{0D}-{0M}-{YYYY}")
    template = if poc_approvals.action == :approved, do: "booking_3", else: "booking_2"
    vars = [approved_at, poc_approvals.legal_entity_poc.poc_name, poc_approvals.legal_entity_poc.phone_number]

    send_to_poc_phone_numbers(template, vars, reward_lead.id)
  end

  defp send_to_poc_phone_numbers(template, vars, reward_lead_id) do
    BookingRewardsLead
    |> join(:inner, [brl], le in LegalEntity, on: le.id == brl.legal_entity_id)
    |> join(:inner, [brl, le], m in LegalEntityPocMapping, on: m.legal_entity_id == le.id)
    |> join(:inner, [brl, le, m], le_poc in LegalEntityPoc, on: m.legal_entity_poc_id == le_poc.id)
    |> where([brl], brl.id == ^reward_lead_id)
    |> select([brl, ..., le_poc], le_poc.phone_number)
    |> Repo.all()
    |> Enum.each(fn number ->
      Exq.enqueue(Exq, "send_sms", BnApis.Whatsapp.SendWhatsappMessageWorker, [number, template, vars])
    end)
  end
end
