defmodule BnApis.Homeloans do
  import Ecto.Query

  alias BnApis.Repo
  alias BnApis.Homeloan.Country
  alias BnApis.Homeloan.Lead
  alias BnApis.Homeloan.LeadStatus
  alias BnApis.Homeloan.LeadStatusNote
  alias BnApis.Homeloan.Status
  alias BnApis.Homeloan.Bank
  alias BnApis.Organizations.Broker
  alias BnApis.Accounts.Credential
  alias BnApis.Accounts.EmployeeCredential
  alias BnApis.Accounts.EmployeeRole
  alias BnApis.Helpers.ApplicationHelper
  alias BnApis.Places.City
  alias BnApis.Homeloan.Document
  alias BnApis.Reminder
  alias BnApis.Calls
  alias BnApis.Helpers.Time
  alias BnApis.Homeloan.LoanDisbursement
  alias BnApis.Homeloan.LeadType
  alias BnApis.Organizations.BrokerCommission
  alias BnApis.Helpers.Utils
  alias BnApis.HomeloansPanel
  alias BnApis.Homeloan.LoanFiles
  alias BnApis.Helpers.S3Helper
  alias BnApis.Homeloan.LoanFileStatus
  alias BnApis.Stories.Schema.Invoice

  @active "ACTIVE"
  @new "NEW"
  @closed "CLOSED"
  @homeloan_panel_page_limit 12

  @employee_panel_duration_filter [
    %{
      "name" => "This Week (Monday to Sunday)",
      "id" => "this_week"
    },
    %{
      "name" => "Last Week (Last Monday to Sunday)",
      "id" => "last_week"
    },
    %{
      "name" => "This Month",
      "id" => "this_month"
    },
    %{
      "name" => "Last Month",
      "id" => "last_month"
    },
    %{
      "name" => "Overall (No date filter)",
      "id" => "overall"
    }
  ]

  @default_duration_id "overall"

  @helpline_numbers %{
    ApplicationHelper.get_mumbai_city_id() => "+918591340739",
    ApplicationHelper.get_pune_city_id() => "+918591340739"
  }

  @default_helpline_number "+918591340739"

  def homeloan_panel_page_limit() do
    @homeloan_panel_page_limit
  end

  def lead_status_list do
    [
      @active,
      @new,
      @closed
    ]
  end

  defp is_phone_number_mandatory(processing_type) do
    if processing_type == Lead.self_processing_type() do
      false
    else
      true
    end
  end

  defp get_existing_leads(_, nil, _pan, _loan_type), do: []

  defp get_existing_leads(_processing_type, phone_number, pan, loan_type) do
    query =
      Lead
      |> join(:inner, [l], ls in LeadStatus, on: ls.id == l.latest_lead_status_id)
      |> where([l, ls], l.phone_number == ^phone_number and l.active == true and ilike(l.pan, ^pan) and ls.status_id != 8)

    if(loan_type not in [nil, ""]) do
      query |> where([l, ls], ilike(l.loan_type, ^loan_type)) |> Repo.all()
    else
      query |> Repo.all()
    end
  end

  ## For broker

  def create_lead(params, session_data) do
    broker_id = session_data |> get_in(["profile", "broker_id"])

    case params do
      %{
        "country_id" => country_id,
        "name" => name
      } ->
        phone_number = params["phone_number"]
        pan = if not is_nil(params["pan"]), do: String.trim(params["pan"]), else: nil

        processing_type = params["processing_type"]
        loan_type = if not is_nil(params["loan_type"]), do: String.trim(params["loan_type"]), else: nil
        is_phone_number_valid = validate_phone_number(country_id, phone_number, processing_type)

        existing_leads = get_existing_leads(processing_type, phone_number, pan, loan_type)

        # for self processing leads phone number is optional

        is_phone_number_mandatory = is_phone_number_mandatory(processing_type)
        is_invalid_param = is_phone_number_mandatory and is_nil(phone_number)

        has_broker_daily_limit_reached = has_broker_daily_limit_reached?(broker_id)

        case {is_phone_number_valid, name, existing_leads, has_broker_daily_limit_reached, is_invalid_param} do
          {_, _, _, _, true} ->
            {:error, "Invalid params"}

          {false, _, _, _, _} ->
            {:error, "Invalid Phone Number"}

          {_, name, _, _, _} when name in [nil, ""] ->
            {:error, "Invalid name"}

          {_, _, _, true, _} ->
            {:error, "Your daily limit has been reached"}

          {_, _, existing_leads, _, _} when existing_leads != [] ->
            {:error, "Lead already present in system"}

          {true, name, [], false, _} ->
            Repo.transaction(fn ->
              try do
                {status, lead} =
                  Lead.create_lead!(
                    phone_number,
                    country_id,
                    name,
                    params["remarks"],
                    broker_id,
                    params["loan_amount"],
                    params["employment_type"],
                    params["lead_creation_date"],
                    params["bank_name"],
                    params["branch_name"],
                    params["loan_type"],
                    params["property_stage"],
                    params["property_type"],
                    params["processing_type"],
                    params["pan"],
                    params["loan_subtype"]
                  )

                case {status, lead} do
                  {:ok, lead} ->
                    Exq.enqueue(Exq, "send_sms", BnApis.SendHomeloanSmsWorker, [
                      lead.id
                    ])

                    %{"lead_id" => lead.id}

                  {:error, error} ->
                    Repo.rollback(error)
                end
              rescue
                error ->
                  # Repo.rollback("Unable to store data")
                  Repo.rollback(Exception.message(error))
              end
            end)
        end

      _ ->
        {:error, "Invalid params"}
    end
  end

  def delete_lead_from_admin(lead_id) do
    case Lead |> Repo.get_by(id: lead_id, active: true) do
      nil ->
        {:error, :not_found}

      lead ->
        update_lead(lead, %{active: false})
    end
  end

  def update_lead(lead, params) do
    existing_leads =
      cond do
        not is_nil(params["phone_number"]) and lead.phone_number != params["phone_number"] ->
          get_existing_leads(lead.processing_type, params["phone_number"], lead.pan, lead.loan_type)

        not is_nil(params["pan"]) and lead.pan != params["pan"] ->
          get_existing_leads(lead.processing_type, lead.phone_number, params["pan"], lead.loan_type)

        not is_nil(params["loan_type"]) and lead.loan_type != params["loan_type"] ->
          get_existing_leads(lead.processing_type, lead.phone_number, lead.pan, params["loan_type"])

        true ->
          []
      end

    if(existing_leads == []) do
      lead |> Lead.changeset(params) |> Repo.update()
    else
      {:error, "lead already present with same phone number, loan type and pan"}
    end
  end

  def update_doc(params, _session_data) do
    homeloan_lead = Lead.get_homeloan_lead(params["homeloan_lead_id"])
    Lead.update_docs!(homeloan_lead, params["docs"])
    {:ok, "lead_updated_successfully"}
  end

  def validate_lead_for_update(homeloan_lead, broker_id) do
    homeloan_lead.broker_id == broker_id
  end

  def mark_sms_consent(params) do
    external_link = params["homeloan_external_link"]

    with lead = Lead.get_lead_from_external_link(external_link),
         false <- is_nil(lead),
         true <- Lead.validate_lead_for_consent(lead),
         params = get_params_for_status_update(lead),
         {:ok, nil} <- update_status(params, %{}) do
      {:ok, "Your Consent was taken successfully."}
    else
      _ ->
        {:error, "Some Error Occured, Please contact your Channel Partner"}
    end
  end

  def lead_list(session_data) do
    broker_id = session_data |> get_in(["profile", "broker_id"])
    broker = Broker.fetch_broker_from_id(broker_id)

    helpline_number = @helpline_numbers[broker.operating_city] || @default_helpline_number

    leads = lead_list_of_broker(broker_id)

    {:ok,
     %{
       "leads" => leads,
       "helpline_number" => helpline_number,
       "home_loan_notification_count" => Lead.hl_notification_count(broker_id)
     }}
  end

  defp lead_list_of_broker(broker_id) do
    Lead
    |> where([l], l.broker_id == ^broker_id and l.active == true)
    |> order_by([l], desc: l.inserted_at)
    |> Repo.all()
    |> Repo.preload([:country, :employee_credentials, :homeloan_documents, homeloan_lead_statuses: from(ls in LeadStatus, order_by: [desc: ls.inserted_at])])
    |> Enum.map(fn lead ->
      employee_creds =
        if not is_nil(lead.employee_credentials) do
          %{
            "name" => lead.employee_credentials.name,
            "phone_number" => lead.employee_credentials.phone_number,
            "id" => lead.employee_credentials.id,
            "uuid" => lead.employee_credentials.uuid
          }
        else
          %{}
        end

      helpline_number = if is_nil(employee_creds["phone_number"]), do: @default_helpline_number, else: employee_creds["phone_number"]

      documents = Document.fetch_lead_docs(lead, _for_admin = false, false)

      %{
        "lead_id" => lead.id,
        "name" => lead.name,
        "country_code" => lead.country.country_code,
        "remarks" => lead.remarks,
        "loan_amount" => lead.loan_amount,
        "phone_number" => lead.phone_number,
        "helpline_number" => helpline_number,
        "assigned_employee" => employee_creds,
        "status_timeline" =>
          lead.homeloan_lead_statuses
          |> Enum.map(fn lead_status ->
            LeadStatus.get_details(lead_status)
          end),
        "documents" => documents,
        "employment_type" => lead.employment_type,
        "is_last_status_seen" => lead.is_last_status_seen,
        "channel_url" => lead.channel_url
      }
    end)
  end

  def get_params_for_status_update(lead) do
    %{
      "lead_id" => lead.id,
      "status_identifier" => "CLIENT_APPROVAL_RECEIVED"
    }
  end

  def lead_list_for_dsa(session_data, page_no, page_size, q, is_employee, params) do
    broker_id = session_data |> get_in(["profile", "broker_id"])
    broker = Broker.fetch_broker_from_id(broker_id)

    helpline_number = @helpline_numbers[broker.operating_city] || @default_helpline_number

    {_query, content_query, total_count, next_page_exists} = lead_list_query(broker_id, page_no, page_size, q, is_employee, params)

    leads =
      content_query
      |> Repo.all()
      |> Repo.preload([
        :country,
        :employee_credentials,
        :homeloan_documents,
        latest_lead_status: [:employee_credential],
        homeloan_lead_statuses: from(ls in LeadStatus, order_by: [desc: ls.inserted_at])
      ])
      |> Enum.map(fn lead -> get_lead_details_response(lead, broker_id, "V1", is_employee) end)

    {:ok,
     %{
       "leads" => leads,
       "helpline_number" => helpline_number,
       "home_loan_notification_count" => Lead.hl_notification_count(broker_id),
       "has_more" => next_page_exists,
       "total_count" => total_count,
       "next_page_query_params" => "p=#{page_no + 1}"
     }}
  end

  def lead_list_query(broker_id, page_no, page_size, q, is_employee, filters) do
    query =
      if is_employee do
        employee_id = Credential.get_employee_id_using_broker_id(broker_id)

        Lead
        |> where([l], l.employee_credentials_id == ^employee_id and l.active == true and l.broker_id != ^broker_id and l.processing_type == "self")
        |> order_by([l], desc: l.inserted_at)
      else
        Lead
        |> where([l], l.broker_id == ^broker_id and l.active == true)
        |> order_by([l], desc: l.inserted_at)
      end

    query =
      query
      |> join(:inner, [l], ls in LeadStatus, on: ls.id == l.latest_lead_status_id)
      |> maybe_add_filter(filters)

    query =
      if not is_nil(q) and q != "" do
        formatted_query = "#{String.downcase(String.trim(q))}%"

        if(is_employee) do
          query
          |> join(:inner, [l, ...], b in Broker, on: l.broker_id == b.id)
          |> where([l, ..., b], fragment("LOWER(?) ilike ?", l.name, ^formatted_query) or fragment("LOWER(?) ilike ?", b.name, ^formatted_query))
        else
          query |> where([l, ls], fragment("LOWER(?) ilike ?", l.name, ^formatted_query))
        end
      else
        query
      end

    content_query =
      query
      |> limit(^page_size)
      |> offset(^((page_no - 1) * page_size))

    total_count = query |> distinct(:id) |> Repo.aggregate(:count, :id)
    next_page_exists = page_no < Float.ceil(total_count / page_size)

    {query, content_query, total_count, next_page_exists}
  end

  def get_leads_using_invoice_status(invoice_status_identifier_list) do
    LoanDisbursement
    |> join(:inner, [l], i in Invoice, on: l.invoice_id == i.id and i.entity_type == :loan_disbursements)
    |> where([l, i], l.active == true and i.status in ^invoice_status_identifier_list)
    |> distinct([l], l.homeloan_lead_id)
    |> select([l, i], l.homeloan_lead_id)
    |> Repo.all()
  end

  defp maybe_add_filter(query, nil), do: query

  defp maybe_add_filter(query, filters) do
    query =
      if(filters["loan_types"] not in [nil, []]) do
        query |> where([l, ls], l.loan_type in ^filters["loan_types"])
      else
        query
      end

    query =
      if(filters["status_identifier_list"] not in [nil, []]) do
        invoice_status_list = filters["status_identifier_list"] |> Enum.filter(fn s -> s in ["invoice_approval_pending", "paid"] end)
        non_invoice_status_list = filters["status_identifier_list"] -- invoice_status_list
        status_ids = non_invoice_status_list |> Enum.map(&Status.get_status_id_from_identifier(&1))

        invoice_status_list =
          if(Enum.member?(invoice_status_list, "invoice_approval_pending")) do
            invoice_status_list ++ ["approved_by_admin", "pending_from_super", "approved_by_super", "approved_by_finance", "invoice_requested"]
          else
            invoice_status_list
          end

        invoice_lead_ids = get_leads_using_invoice_status(invoice_status_list)
        query |> where([l, ls], ls.status_id in ^status_ids or l.id in ^invoice_lead_ids)
      else
        query
      end

    query =
      if(not is_nil(filters["date_filter"])) do
        date_filter_id = filters["date_filter"]["id"]
        date_range = Time.get_date_range_by_id(date_filter_id)

        if(is_nil(date_range)) do
          date_filter_range = filters["date_filter"]["range"]

          if(date_filter_range not in [nil, []] and length(date_filter_range) == 2) do
            start_time = Time.get_beginning_of_the_day_for_unix(List.first(date_filter_range))
            end_time = Time.get_end_of_the_day_for_unix(List.last(date_filter_range))
            query |> where([l, ls], fragment("? BETWEEN ? AND ?", l.lead_creation_date, ^start_time, ^end_time))
          else
            query
          end
        else
          query |> where([l, ls], fragment("? BETWEEN ? AND ?", l.lead_creation_date, ^List.first(date_range), ^List.last(date_range)))
        end
      else
        query
      end

    if(filters["bank_ids"] not in [nil, []]) do
      bank_sub_query = sub_query_bank_loan_files(filters["bank_ids"])

      query
      |> join(:inner, [l, ls], hb in subquery(bank_sub_query), on: l.id == hb.homeloan_lead_id)
      |> where([l, ls, hb], fragment("? :: integer[] && ?", hb.bank_ids, ^filters["bank_ids"]))
    else
      query
    end
  end

  defp sub_query_bank_loan_files(bank_ids) do
    bank_names = Bank.get_bank_data(bank_ids) |> Enum.map(& &1.name)

    loan_file_query =
      LoanFiles
      |> where([lf], lf.active == true and lf.bank_id in ^bank_ids)
      |> select([lf], %{homeloan_lead_id: lf.homeloan_lead_id, bank_id: lf.bank_id})

    Lead
    |> join(:inner, [l], ba in Bank, on: ba.name == l.bank_name and ba.active == true)
    |> join(:inner, [l, ba], ls in LeadStatus, on: ls.id == l.latest_lead_status_id and ls.status_id == 7)
    |> where([l, ls, ba], l.active == true and l.bank_name in ^bank_names)
    |> select([l, ls, ba], %{homeloan_lead_id: l.id, bank_id: ba.id})
    |> union(^loan_file_query)
    |> subquery()
    |> group_by([s], s.homeloan_lead_id)
    |> select([s], %{homeloan_lead_id: s.homeloan_lead_id, bank_ids: fragment("array_agg(?)", s.bank_id)})
  end

  def country_list() do
    countries =
      Repo.all(from(c in Country, where: c.is_operational == true, order_by: c.order))
      |> Enum.map(&country_details(&1))

    {:ok, %{"countries" => countries}}
  end

  ## For employee
  def aggregate_leads(params, session_data, version \\ "V1") do
    city_id = params["city_id"]
    duration_id = params["duration_id"] || @default_duration_id
    polygon_ids = params["polygon_ids"]
    employee_id = session_data |> get_in(["profile", "employee_id"])
    employee_role_id = session_data |> get_in(["profile", "employee_role_id"])
    access_city_ids = session_data |> get_in(["profile", "access_city_ids"])

    employee_credential_id =
      if not is_nil(employee_role_id) and employee_role_id in [EmployeeRole.hl_agent().id, EmployeeRole.dsa_agent().id, EmployeeRole.dsa_admin().id, EmployeeRole.dsa_super().id] do
        employee_id
      else
        params["employee_credential_id"]
      end

    {lead_agg_data, lead_status_data} = get_lead_agg_data(city_id, duration_id, employee_credential_id, polygon_ids, access_city_ids, employee_role_id, version)

    duration_filter =
      @employee_panel_duration_filter
      |> Enum.map(fn duration ->
        Map.put(duration, "is_selected", duration_id == duration["id"])
      end)

    city_filter =
      City.get_cities_list()
      |> Enum.map(fn city ->
        Map.put(city, "is_selected", city_id == city["id"])
      end)

    response = %{
      "lead_agg_data" => lead_agg_data,
      "duration" => duration_filter,
      "city" => city_filter,
      "lead_status_data" => lead_status_data
    }

    {:ok, response}
  end

  def list_leads_by_status(params, session_data, version \\ "V1") do
    city_id = params["city_id"]
    duration_id = params["duration_id"] || @default_duration_id
    polygon_ids = params["polygon_ids"]
    employee_id = session_data |> get_in(["profile", "employee_id"])
    employee_role_id = session_data |> get_in(["profile", "employee_role_id"])
    access_city_ids = session_data |> get_in(["profile", "access_city_ids"])

    order_by =
      if(not is_nil(params["order_by"]) and params["order_by"] != "") do
        case Jason.decode(Map.get(params, "order_by")) do
          {:ok, data} -> data
          {:error, _} -> nil
        end
      else
        nil
      end

    employee_credential_id =
      if not is_nil(employee_role_id) and employee_role_id in [EmployeeRole.hl_agent().id, EmployeeRole.dsa_agent().id, EmployeeRole.dsa_admin().id, EmployeeRole.dsa_super().id] do
        employee_id
      else
        params["employee_credential_id"]
      end

    status_id = Status.get_status_id_from_identifier(params["status_identifier"])

    page_no = (params["p"] || "1") |> String.to_integer()

    filter_leads(
      status_id,
      city_id,
      duration_id,
      employee_credential_id,
      polygon_ids,
      page_no,
      true,
      access_city_ids,
      params["status"],
      order_by,
      params["q"],
      employee_role_id,
      version
    )
  end

  def update_status(%{"lead_id" => homeloan_lead_id} = params, session_data, version \\ "V1") do
    status_identifier = params["status_identifier"]
    employee_id = session_data |> get_in(["profile", "employee_id"])

    bank_ids = params["bank_ids"]

    if is_nil(params["bank_ids"]),
      do: nil,
      else: Enum.reject(params["bank_ids"], &is_nil(&1))

    amount = params["amount"]
    note = params["note"] || params["rejected_lost_reason"]

    status_id = Status.get_status_id_from_identifier(params["status_identifier"])

    homeloan_lead = Lead.get_homeloan_lead(homeloan_lead_id)
    homeloan_lead = Repo.preload(homeloan_lead, [:broker, broker: [:credentials]])

    {is_valid_params, message, updated_params} = validate_update_status_params(params, bank_ids, amount, note, homeloan_lead, version)

    case is_valid_params do
      false ->
        {:error, message}

      true ->
        Repo.transaction(fn ->
          try do
            update_lead(homeloan_lead, updated_params)
            latest_lead_status = LeadStatus.get_lead_status(homeloan_lead.latest_lead_status_id)

            {latest_lead_status, enqueue_send_notification} =
              if is_nil(latest_lead_status) ||
                   status_id != latest_lead_status.status_id do
                {LeadStatus.create_lead_status!(
                   homeloan_lead,
                   status_id,
                   bank_ids,
                   amount,
                   employee_id,
                   params["loan_file_id"]
                 ), true}
              else
                {latest_lead_status, false}
              end

            if !is_nil(note) && note != "" do
              LeadStatusNote.create_lead_status_note!(
                note,
                latest_lead_status.id,
                employee_id
              )
            end

            if enqueue_send_notification do
              Exq.enqueue(
                Exq,
                "send_notification",
                BnApis.SendHomeloanNotificationWorker,
                [homeloan_lead.id]
              )
            end

            if status_identifier == "HOME_LOAN_DISBURSED" and version == "V2" do
              params = updated_params |> Map.put("lead_id", homeloan_lead.id)

              case LoanDisbursement.add_homeloan_disbursement(params) do
                {:ok, _changeset} ->
                  if(params["disbursement_type"] == LoanDisbursement.full_disbursement()["name"]) do
                    update_lead(homeloan_lead, %{"fully_disbursed" => true})
                  end

                {:error, error} ->
                  {:error, error}
              end
            end

            nil
          rescue
            _error ->
              Repo.rollback("Unable to store data")
          end
        end)
    end
  end

  def update_status(_params, _session_data, _version) do
    {:error, "Invalid params"}
  end

  def update_lead_status_for_dsa(params, broker_id, version \\ "V1") do
    status_identifier = params["status_identifier"]
    status_id = Status.get_status_id_from_identifier(status_identifier)
    homeloan_lead = Lead.get_homeloan_lead(params["lead_id"])
    homeloan_lead = Repo.preload(homeloan_lead, [:broker, broker: [:credentials]])
    {is_valid_params, message, updated_params} = validate_update_status_params_for_dsa(status_identifier, params, homeloan_lead, version)

    bank_id =
      if not is_nil(homeloan_lead) and not is_nil(homeloan_lead.bank_name) and status_identifier == "PROCESSING_DOC_IN_BANKS" do
        bank_id = Bank.get_bank_id_by_name(homeloan_lead.bank_name)
        [bank_id]
      else
        nil
      end

    case is_valid_params do
      false ->
        {:error, message}

      true ->
        Repo.transaction(fn ->
          try do
            update_lead(homeloan_lead, updated_params)
            latest_lead_status = LeadStatus.get_lead_status(homeloan_lead.latest_lead_status_id)

            if is_nil(latest_lead_status) || status_id != latest_lead_status.status_id do
              LeadStatus.create_lead_status!(
                homeloan_lead,
                status_id,
                bank_id,
                nil,
                nil,
                params["loan_file_id"]
              )
            else
              latest_lead_status
            end

            if(status_identifier == "HOME_LOAN_DISBURSED") do
              case version do
                "V1" ->
                  commission = BrokerCommission.calculate_broker_commission(params["loan_disbursed"], homeloan_lead.loan_type, broker_id, homeloan_lead.processing_type)
                  params = updated_params |> Map.put("loan_commission", commission) |> Map.put("lead_id", homeloan_lead.id)
                  LoanDisbursement.add_homeloan_disbursement(params)

                "V2" ->
                  LoanDisbursement.add_homeloan_disbursement(params)
              end

              if(params["disbursement_type"] == LoanDisbursement.full_disbursement()["name"]) do
                update_lead(homeloan_lead, %{"fully_disbursed" => true})
              end
            end

            nil
          rescue
            _error ->
              Repo.rollback("Unable to store data")
          end
        end)
    end
  end

  def add_note(%{"lead_id" => homeloan_lead_id, "note" => note}, session_data) do
    employee_id = session_data |> get_in(["profile", "employee_id"])
    homeloan_lead = Lead.get_homeloan_lead(homeloan_lead_id)

    latest_lead_status = LeadStatus.get_lead_status(homeloan_lead.latest_lead_status_id)

    if !is_nil(latest_lead_status) && !is_nil(note) && note != "" do
      Repo.transaction(fn ->
        try do
          LeadStatusNote.create_lead_status_note!(
            note,
            latest_lead_status.id,
            employee_id
          )

          nil
        rescue
          _ ->
            Repo.rollback("Unable to store data")
        end
      end)
    else
      {:error, "Invalid params"}
    end
  end

  def add_note(_params, _session_data) do
    {:error, "Invalid params"}
  end

  def list_leads_by_phone(params, session_data, version \\ "V1") do
    phone_number = params["phone_number"]

    page_no = (params["p"] || "1") |> String.to_integer()
    employee_id = session_data |> get_in(["profile", "employee_id"])
    employee_role_id = session_data |> get_in(["profile", "employee_role_id"])
    access_city_ids = session_data |> get_in(["profile", "access_city_ids"])

    employee_credential_id =
      if not is_nil(employee_role_id) and employee_role_id in [EmployeeRole.hl_agent().id, EmployeeRole.dsa_agent().id, EmployeeRole.dsa_admin().id, EmployeeRole.dsa_super().id] do
        employee_id
      else
        nil
      end

    filter_leads(phone_number, page_no, employee_credential_id, access_city_ids, params["status"], employee_role_id, version)
  end

  def transfer_leads(nil, _lead_ids) do
    %{"message" => "Employee to transfer is required"}
  end

  def transfer_leads(employee_to_transfer, lead_ids, user_map) do
    Repo.transaction(fn ->
      try do
        lead_ids
        |> Enum.each(fn lid ->
          Lead.transfer_lead(lid, employee_to_transfer, user_map)
        end)

        %{"message" => "Success"}
      rescue
        err ->
          Repo.rollback(Exception.message(err))
      end
    end)
  end

  def update_active_hl_agents(params, user_map) do
    try do
      params["employee_map"]
      |> Enum.each(fn em ->
        case EmployeeCredential.update_hl_flag(elem(em, 0), elem(em, 1), user_map) do
          {:ok, emp} -> {:ok, emp}
          {:error, changeset} -> throw({:break, changeset})
        end
      end)

      {:ok, %{"message" => "Success"}}
    catch
      {:break, changeset} -> {:error, changeset}
    end
  end

  def homeloan_leads_count(broker_ids) do
    Lead
    |> where([l], l.broker_id in ^broker_ids and l.active == true)
    |> Repo.aggregate(:count, :id)
  end

  def handle_lead_squared_webhook(params) do
    Repo.transaction(fn ->
      try do
        if params["eventType"] == "Lead_Post_Stage_Change" do
          from_lead_squared_uuid = params["Before"]["ProspectID"]
          # from_status = params["Before"]["ProspectStage"]
          # from_status_modified_on = params["Before"]["ModifiedOn"]

          to_lead_squared_uuid = params["After"]["ProspectID"]
          to_status = params["After"]["ProspectStage"]
          email = params["After"]["OwnerIdEmailAddress"]
          credential = EmployeeCredential.fetch_employee_credential_by_email(email)

          employee_credential_id =
            if !is_nil(credential) do
              credential.id
            else
              nil
            end

          comments = params["After"]["StageChangeComment"]

          if from_lead_squared_uuid == to_lead_squared_uuid do
            lead = Repo.get_by(Lead, lead_squared_uuid: to_lead_squared_uuid)

            if not is_nil(lead) do
              status_id =
                to_status
                |> String.replace("\s", "_")
                |> String.upcase()
                |> Status.get_status_id_from_identifier()

              lead_status = LeadStatus.create_lead_status!(lead, status_id, nil, nil, employee_credential_id, params["loan_file_id"])

              if !is_nil(comments) && comments != "" do
                LeadStatusNote.create_lead_status_note!(
                  comments,
                  lead_status.id,
                  employee_credential_id
                )
              end
            end
          end
        end

        %{"message" => "Success"}
      rescue
        _ ->
          Repo.rollback("Unable to process lead_squared webhook")
      end
    end)
  end

  ### Private methods

  defp country_details(%Country{} = country) do
    %{
      "id" => country.id,
      "name" => country.name,
      "country_code" => country.country_code,
      "url_name" => country.url_name,
      "phone_validation_regex" => country.phone_validation_regex
    }
  end

  defp validate_update_status_params(_params, _bank_ids, _amount, _note, nil, _version), do: {false, "Invalid Lead", %{}}

  defp validate_update_status_params(params, bank_ids, amount, note, _lead, "V1") do
    statuses = Status.status_list() |> Enum.map(fn {_st, val} -> val end) |> Enum.map(& &1["identifier"])
    status_identifier = params["status_identifier"]
    message = nil
    updated_params = %{}

    {updated_params, message} =
      case status_identifier do
        "FAILED" ->
          message = validate_field(message, "note", note)
          {updated_params, message}

        "PROCESSING_DOC_IN_BANKS" ->
          message = if bank_ids in [nil, []], do: "bank ids are missing", else: message
          {updated_params, message}

        "SANCTION_LETTER_ISSUED" ->
          message = message |> validate_field("Sanction amount", params["sanctioned_amount"])
          updated_params = params |> Map.take(["sanctioned_amount"])
          {updated_params, message}

        "OFFER_RECEIVED_FROM_BANKS" ->
          message = if bank_ids in [nil, []], do: "bank ids are missing", else: message
          {updated_params, message}

        "HOME_LOAN_DISBURSED" ->
          message = if bank_ids in [nil, []], do: "bank ids are missing", else: message
          {updated_params, message}

        "COMMISSION_RECEIVED" ->
          message = message |> validate_field("amount", amount)
          {updated_params, message}

        status_identifier ->
          message = if Enum.member?(statuses, status_identifier), do: message, else: "Invalid Status"
          {updated_params, message}
      end

    if is_nil(message), do: {true, message, updated_params}, else: {false, message, updated_params}
  end

  defp validate_update_status_params(params, _bank_ids, _amount, note, lead, "V2") do
    statuses = Status.status_list() |> Enum.map(fn {_st, val} -> val end) |> Enum.map(& &1["identifier"])
    status_identifier = params["status_identifier"]
    message = nil

    {updated_params, message} =
      case status_identifier do
        "FAILED" ->
          message = validate_field(message, "note", note)
          params = params |> Map.put("rejected_lost_reason", note)
          updated_params = params |> Map.take(["rejected_lost_reason", "rejected_doc_url"])
          {updated_params, message}

        "PROCESSING_DOC_IN_BANKS" ->
          {%{}, message}

        "SANCTION_LETTER_ISSUED" ->
          message =
            message
            |> validate_field("Bank rm phone number", params["bank_rm_phone_number"], lead)
            |> validate_field("Bank rm name", params["bank_rm_name"])
            |> validate_field("Sanction amount", params["sanctioned_amount"])
            |> validate_field("Sanction document", params["sanctioned_doc_url"])

          {%{}, message}

        "OFFER_RECEIVED_FROM_BANKS" ->
          {%{}, message}

        "HOME_LOAN_DISBURSED" ->
          message =
            if params["disbursement_type"] == LoanDisbursement.full_disbursement()["name"] do
              message = validate_field(message, "Otc cleared", params["otc_cleared"])
              validate_field(message, "Pdd cleared", params["pdd_cleared"])
            else
              nil
            end

          message =
            message
            |> validate_field("loan disbursed", params["loan_disbursed"])
            |> validate_field("lan", params["lan"])
            |> validate_field("Disbursement type", params["disbursement_type"])
            |> validate_field("Document url", params["document_url"])
            |> validate_field("Disbursement date", params["disbursement_date"])
            |> case do
              nil ->
                sanctioned_amount = LoanFiles.get_loan_file(params["loan_file_id"]).sanctioned_amount

                if(sanctioned_amount < params["loan_disbursed"]) do
                  "Disburse Amount can't exceed the sanctioned amount"
                else
                  nil
                end

              message ->
                message
            end

          updated_params =
            params
            |> Map.take([
              "otc_cleared",
              "pdd_cleared",
              "lan",
              "disbursement_type",
              "document_url",
              "loan_disbursed",
              "disbursement_date",
              "loan_file_id",
              "otc_pdd_proof_doc",
              "disbursed_with"
            ])

          {updated_params, message}

        status_identifier ->
          message = if Enum.member?(statuses, status_identifier), do: message, else: "Invalid Status"
          {%{}, message}
      end

    if is_nil(message), do: {true, message, updated_params}, else: {false, message, updated_params}
  end

  def validate_update_status_params_for_dsa(_status_identifier, _params, nil, _version), do: {false, "Invalid Lead", %{}}

  def validate_update_status_params_for_dsa(status_identifier, params, lead, version) do
    disbursement_types = [LoanDisbursement.partial_disbursement()["name"], LoanDisbursement.full_disbursement()["name"]]
    message = nil

    {updated_params, message} =
      case status_identifier do
        "PROCESSING_DOC_IN_BANKS" ->
          message = validate_field(message, "Application Id", params["application_id"])
          updated_params = params |> Map.take(["application_id"])
          {updated_params, message}

        "SANCTION_LETTER_ISSUED" ->
          bank_rm_key_name = if version == "V1", do: params["bank_rm"], else: params["bank_rm_name"]

          message =
            message
            |> validate_field("Bank rm phone number", params["bank_rm_phone_number"], lead)
            |> validate_field("Bank rm name", bank_rm_key_name)
            |> validate_field("Sanction amount", params["sanctioned_amount"])
            |> validate_field("Sanction document", params["sanctioned_doc_url"])

          updated_params = params |> Map.take(["bank_name", "bank_rm_phone_number", "bank_rm", "sanctioned_doc_url", "sanctioned_amount"])
          {updated_params, message}

        "HOME_LOAN_DISBURSED" ->
          message = if Enum.member?(disbursement_types, params["disbursement_type"]), do: message, else: "Invalid disbursement type"

          message =
            if params["disbursement_type"] == LoanDisbursement.full_disbursement()["name"] do
              message = validate_field(message, "Otc cleared", params["otc_cleared"])
              validate_field(message, "Pdd cleared", params["pdd_cleared"])
            else
              nil
            end

          message =
            message
            |> validate_field("loan disbursed", params["loan_disbursed"])
            |> validate_field("lan", params["lan"])
            |> validate_field("Disbursement type", params["disbursement_type"])
            |> validate_field("Document url", params["document_url"])
            |> validate_field("Disbursement date", params["disbursement_date"])
            |> case do
              nil ->
                sanctioned_amount = LoanFiles.get_loan_file(params["loan_file_id"]).sanctioned_amount

                if(sanctioned_amount < params["loan_disbursed"]) do
                  "Disburse Amount can't exceed the sanctioned amount"
                else
                  nil
                end

              message ->
                message
            end

          updated_params = params |> Map.take(["otc_cleared", "pdd_cleared", "lan", "disbursement_type", "document_url", "loan_disbursed", "disbursement_date"])
          {updated_params, message}

        "FAILED" ->
          updated_params = params |> Map.take(["rejected_doc_url", "rejected_lost_reason"])
          {updated_params, message}

        _ ->
          {%{}, message}
      end

    if is_nil(message), do: {true, message, updated_params}, else: {false, message, updated_params}
  end

  defp validate_phone_number(_, "", "self") do
    true
  end

  defp validate_phone_number(_, nil, "self") do
    true
  end

  defp validate_phone_number(nil, _phone_number, _) do
    false
  end

  defp validate_phone_number(_country_id, nil, _) do
    false
  end

  defp validate_phone_number(country_id, phone_number, _) do
    country = Country.get_country(country_id)
    String.match?(phone_number, ~r/#{country.phone_validation_regex}/)
  end

  defp validate_field(message, field_name, field_value, lead) when field_name == "Bank rm phone number" do
    credentials = List.first(lead.broker.credentials)

    cond do
      credentials.phone_number == field_value ->
        "Invalid params"

      validate_phone_number("1", field_value, "") == false ->
        "Invalid RM phone number"

      true ->
        message
    end
  end

  defp validate_field(_message, field_name, field_value) when is_nil(field_value) or field_value == "", do: "#{field_name} is missing"
  defp validate_field(message, _field_name, _field_value), do: message

  defp has_broker_daily_limit_reached?(broker_id) do
    daily_max_lead_count = 50

    today =
      Timex.now()
      |> Timex.Timezone.convert("Asia/Kolkata")
      |> Timex.beginning_of_day()

    brokers_today_lead_count =
      Repo.one(
        from(l in Lead,
          where: l.broker_id == ^broker_id,
          where: l.inserted_at >= ^today,
          select: count(l.id)
        )
      )

    brokers_today_lead_count >= daily_max_lead_count
  end

  defp is_lead_editable(_lead, true), do: false

  defp is_lead_editable(lead, _) do
    if lead.processing_type in [Lead.self_processing_type(), Lead.bn_processing_type()] do
      if Status.get_status_from_id(lead.latest_lead_status.status_id)["identifier"] in ["CLIENT_APPROVAL_RECEIVED", "PROCESSING_DOC_IN_BANKS"], do: true, else: false
    else
      false
    end
  end

  defp get_lead_details_response(lead, broker_id, version, is_employee_view, add_detailed_response \\ false) do
    lead = Repo.preload(lead, :broker)
    loan_disbursements = get_loan_disbursements(lead.id, is_employee_view)
    employment_type = LeadType.employment_type_list() |> Enum.find(&(&1.id == lead.employment_type)) || %{}
    logged_in_broker = Broker.fetch_broker_from_id(broker_id)
    credential = Credential.get_credential_from_broker_id(lead.broker.id)

    employee_creds =
      if not is_nil(lead.employee_credentials) do
        %{
          "name" => lead.employee_credentials.name,
          "phone_number" => lead.employee_credentials.phone_number,
          "id" => lead.employee_credentials.id,
          "uuid" => lead.employee_credentials.uuid
        }
      else
        %{}
      end

    helpline_number = if is_nil(employee_creds["phone_number"]), do: @default_helpline_number, else: employee_creds["phone_number"]
    is_editable = is_lead_editable(lead, is_employee_view)

    lead_details = %{
      "lead_id" => lead.id,
      "name" => lead.name,
      "country_code" => lead.country.country_code,
      "remarks" => lead.remarks,
      "display_required_loan_amount" => Utils.format_money_new(lead.loan_amount),
      "required_loan_amount" => lead.loan_amount,
      "phone_number" => lead.phone_number,
      "helpline_number" => helpline_number,
      "assigned_employee" => employee_creds,
      "employment_type" => lead.employment_type,
      "employment_type_name" => employment_type |> Map.get(:name),
      "is_last_status_seen" => lead.is_last_status_seen,
      "channel_url" => lead.channel_url,
      "lead_creation_date" => lead.lead_creation_date,
      "lead_created_date_unix" => Time.naive_to_epoch_in_sec(lead.inserted_at),
      "bank_name" => lead.bank_name,
      "branch_name" => lead.branch_name,
      "fully_disbursed" => lead.fully_disbursed,
      "loan_type" => lead.loan_type,
      "property_stage" => lead.property_stage,
      "processing_type" => lead.processing_type,
      "application_id" => lead.application_id,
      "bank_rm" => lead.bank_rm,
      "bank_rm_phone_number" => lead.bank_rm_phone_number,
      "sanctioned_amount" => lead.sanctioned_amount,
      "display_sanctioned_amount" => Utils.format_money_new(lead.sanctioned_amount),
      "rejected_lost_reason" => lead.rejected_lost_reason,
      "property_type" => lead.property_type,
      "is_editable" => is_editable,
      "current_status" => %{
        "status_name" => Status.get_status_from_id(lead.latest_lead_status.status_id)["display_name"],
        "status_identifier" => Status.get_status_from_id(lead.latest_lead_status.status_id)["identifier"],
        "status_id" => lead.latest_lead_status.status_id,
        "updated_at" => lead.latest_lead_status.updated_at,
        "updated_at_unix" => Time.naive_to_epoch_in_sec(lead.latest_lead_status.updated_at),
        "updated_by" => if(is_nil(lead.latest_lead_status.employee_credential), do: nil, else: lead.latest_lead_status.employee_credential.id),
        "bg_color_code" => Status.get_status_from_id(lead.latest_lead_status.status_id)["bg_color_code"],
        "text_color_code" => Status.get_status_from_id(lead.latest_lead_status.status_id)["text_color_code"]
      },
      "lead_action" => get_lead_next_action(lead, is_employee_view, logged_in_broker.is_employee, loan_disbursements["disbursements"], add_detailed_response),
      "total_disbursed" => loan_disbursements["total_disbursed"],
      "lan" => loan_disbursements["loan_account_number"],
      "pan" => lead.pan,
      "loan_subtype" => lead.loan_subtype,
      "broker_info" => %{
        "name" => lead.broker.name,
        "contact_number" => credential.phone_number,
        "country_code" => credential.country_code
      }
    }

    if add_detailed_response == true do
      lead_details |> Map.merge(get_more_lead_details(lead, logged_in_broker, loan_disbursements["disbursements"], version, is_employee_view))
    else
      lead_details
    end
  end

  defp allow_add_documents(_lead, true), do: false

  defp allow_add_documents(lead, _) do
    if lead.processing_type == Lead.self_processing_type(), do: false, else: true
  end

  def get_more_lead_details(lead, logged_in_broker, disbursements, version, is_employee_view) do
    allow_add_documents? = allow_add_documents(lead, is_employee_view)

    {status_timeline, documents} =
      if logged_in_broker.role_type_id in [nil, Broker.real_estate_broker()["id"]] do
        status_timeline =
          case version do
            "V1" ->
              lead.homeloan_lead_statuses
              |> Enum.map(fn lead_status -> LeadStatus.get_details(lead_status) end)
              |> Enum.sort_by(& &1["updated_at_unix"], :desc)

            "V2" ->
              get_loan_file_status_timeline(lead, true)
          end

        documents = Document.fetch_lead_docs(lead, _for_admin = false, false)
        {status_timeline, documents}
      else
        status_timeline = add_status_timeline_for_dsa(lead, disbursements, version)

        documents = Lead.get_documents_based_on_lead_type(lead, version, is_employee_view)

        {status_timeline, documents}
      end

    %{
      # will remove branch_location
      "branch_location" => if(not is_nil(lead.city_id), do: City.get_city_by_id(lead.city_id).name, else: nil),
      "property_stage" => lead.property_stage,
      "documents" => documents,
      "location_of_dsa" => if(not is_nil(lead.broker.operating_city), do: City.get_city_by_id(lead.broker.operating_city).name, else: nil),
      "status_timeline" => status_timeline,
      "disbursements" => disbursements,
      "allow_add_documents" => allow_add_documents?,
      "loan_files" => LoanFiles.get_loan_files(lead.id, _is_admin = false),
      "loan_subtype" => lead.loan_subtype
    }
  end

  def get_loan_file_status_timeline(lead, add_lead_statuses \\ false) do
    lead = Repo.preload(lead, :loan_files)

    loan_file_statuses =
      Enum.reduce(lead.loan_files, [], fn loan_file, acc ->
        loan_file = loan_file |> Repo.preload(:loan_file_statuses)
        acc ++ loan_file.loan_file_statuses
      end)

    loan_file_statuses =
      loan_file_statuses
      |> Enum.map(&LeadStatus.get_loan_file_details(&1, true, true))
      |> Enum.sort_by(& &1["updated_at_unix"], :desc)

    if add_lead_statuses, do: add_lead_statuses(lead, loan_file_statuses), else: loan_file_statuses
  end

  def add_lead_statuses(lead, loan_file_statuses) do
    add_loan_file_bank_and_amount = if(lead.loan_files in [nil, []], do: false, else: true)

    homeloan_lead_statuses =
      lead.homeloan_lead_statuses
      |> Enum.map(&LeadStatus.get_details(&1, true, true, add_loan_file_bank_and_amount))

    homeloan_lead_statuses =
      if(add_loan_file_bank_and_amount) do
        homeloan_lead_statuses |> Enum.filter(fn lead_status -> lead_status["status_identifier"] in ["CLIENT_APPROVAL_RECEIVED", "FAILED"] end)
      else
        homeloan_lead_statuses
      end

    (loan_file_statuses ++ homeloan_lead_statuses) |> Enum.sort_by(& &1["updated_at_unix"], :desc)
  end

  def add_status_timeline_for_dsa(lead, loan_disbursements, _version) do
    non_disburse_lead_statuses = LoanFileStatus.get_file_statuses_of_lead(lead) |> Enum.filter(fn x -> x.status_id != 6 end)

    non_disburse_status_timeline =
      non_disburse_lead_statuses
      |> Enum.map(fn lead_status ->
        LeadStatus.get_loan_file_details(lead_status, false, false) |> Map.put("description_keys", set_lead_status_description(lead_status, nil))
      end)

    if Enum.any?(lead.homeloan_lead_statuses, fn x -> x.status_id == 6 end) do
      disbursed_lead_status = lead.homeloan_lead_statuses |> Enum.find(fn x -> x.status_id == 6 end)
      disbursed_lead_status_details = LeadStatus.get_loan_file_details(disbursed_lead_status, false, false)

      if(not is_nil(disbursed_lead_status) and length(loan_disbursements) > 0) do
        updated_status_timeline =
          loan_disbursements
          |> Enum.map(fn disbursement ->
            description =
              Status.status_list()[disbursed_lead_status.status_id] |> Map.get("text") |> String.replace("<amount>", Utils.format_money_new(disbursement.loan_disbursed))

            disbursed_lead_status_details
            |> Map.put("description", description)
            |> Map.put("description_keys", set_lead_status_description(disbursed_lead_status, disbursement))
            |> Map.put("updated_at_unix", Time.naive_to_epoch_in_sec(disbursement.inserted_at))
            |> Map.put("updated_at", disbursement.inserted_at)
            |> Map.put("disbursement_type", disbursement.disbursement_type)
          end)

        (updated_status_timeline ++ non_disburse_status_timeline) |> Enum.sort_by(& &1["updated_at_unix"], :desc)
      else
        disburse_status_timeline = disbursed_lead_status_details |> Map.put("description_keys", set_lead_status_description(disbursed_lead_status, nil))
        (non_disburse_status_timeline ++ [disburse_status_timeline]) |> Enum.sort_by(& &1["updated_at_unix"], :desc)
      end
    else
      non_disburse_status_timeline |> Enum.sort_by(& &1["updated_at_unix"], :desc)
    end
  end

  def set_lead_status_description(current_lead_status, loan_disbursement) do
    current_lead_status = current_lead_status |> Repo.preload(:loan_file)
    status = Status.get_status_from_id(current_lead_status.status_id)["identifier"]

    cond do
      status == "PROCESSING_DOC_IN_BANKS" ->
        "Application ID: #{current_lead_status.loan_file.application_id}"

      status == "SANCTION_LETTER_ISSUED" ->
        bank_name = Bank.get_bank_name_from_id(current_lead_status.loan_file.bank_id)
        "Bank Name: #{bank_name}\nBank RM: #{current_lead_status.loan_file.bank_rm_name}\nContact: #{current_lead_status.loan_file.bank_rm_phone_number}"

      status == "HOME_LOAN_DISBURSED" and not is_nil(loan_disbursement) ->
        otc_cleared = if loan_disbursement.otc_cleared in [true, "true"], do: "Yes", else: "No"
        pdd_cleared = if loan_disbursement.pdd_cleared in [true, "true"], do: "Yes", else: "No"
        "OTC Cleared: #{otc_cleared}\nPDD Cleared: #{pdd_cleared}\nLAN: #{loan_disbursement.lan}"

      status == "FAILED" ->
        "Reason For Loss :#{current_lead_status.loan_file.rejected_lost_reason}"

      true ->
        ""
    end
  end

  def get_lead_data(params, broker_id, version) do
    query =
      if is_nil(params["is_employee"]) do
        Lead
        |> where([l], l.id == ^params["lead_id"] and l.broker_id == ^broker_id)
      else
        employee_id = Credential.get_employee_id_using_broker_id(broker_id)

        Lead
        |> where([l], l.id == ^params["lead_id"] and l.employee_credentials_id == ^employee_id)
      end

    lead =
      query
      |> Repo.one()
      |> Repo.preload([:country, :employee_credentials, :homeloan_documents, :homeloan_lead_statuses, latest_lead_status: [:employee_credential]])

    if is_nil(lead) do
      {:error, :not_found}
    else
      format_lead_details_response(lead, broker_id, params, version)
    end
  end

  def format_lead_details_response(lead, broker_id, params, version) do
    is_employee_view = if is_nil(params["is_employee"]), do: false, else: true
    broker = Broker.fetch_broker_from_id(broker_id)
    helpline_number = @helpline_numbers[broker.operating_city] || @default_helpline_number

    lead_details = get_lead_details_response(lead, broker_id, version, is_employee_view, _add_detailed_response = true)

    {:ok,
     %{
       "helpline_number" => helpline_number,
       "home_loan_notification_count" => 0,
       "lead" => lead_details
     }}
  end

  def get_loan_disbursements(lead_id, is_employee) do
    disbursement = LoanDisbursement.get_loan_disbursements(lead_id, is_employee)
    total_disbursed_amount = disbursement |> Enum.reduce(0, fn dis, acc -> acc + (dis.loan_disbursed || 0) end)
    total_commission_amount = disbursement |> Enum.reduce(0, fn dis, acc -> acc + (dis.loan_commission || 0) end)
    disbursement_type = if not is_nil(List.first(disbursement)), do: List.first(disbursement).disbursement_type, else: nil
    disbursement_date = if not is_nil(List.first(disbursement)), do: List.first(disbursement).disbursement_date, else: nil
    loan_account_number = if not is_nil(List.first(disbursement)), do: List.first(disbursement).lan, else: nil

    loan_file_id =
      if length(disbursement) > 0 do
        any_ld = disbursement |> List.first()
        any_ld.loan_file_id
      else
        nil
      end

    {application_id, bank_name, bank_logo_url, branch_location, sanctioned_amount} =
      if is_nil(loan_file_id) do
        {nil, nil, nil, nil, nil}
      else
        loan_file = Repo.get_by(LoanFiles, id: loan_file_id)

        {loan_file.application_id, Bank.get_bank_name_from_id(loan_file.bank_id), Bank.get_bank_logo_url_from_id(loan_file.bank_id), loan_file.branch_location,
         loan_file.sanctioned_amount}
      end

    lead = Repo.get_by(Lead, id: lead_id)
    is_editable = is_disbursement_editable(lead.processing_type, is_employee)

    %{
      "loan_account_number" => loan_account_number,
      "total_disbursed" => %{
        "display_total_disbursed_amount" => Utils.format_money_new(total_disbursed_amount),
        "total_disbursed_amount" => total_disbursed_amount,
        "display_total_commission_amount" => Utils.format_money_new(total_commission_amount),
        "total_commission_amount" => total_commission_amount,
        "disbursement_type" => disbursement_type,
        "disbursement_date" => disbursement_date,
        "application_id" => application_id,
        "bank_name" => bank_name,
        "bank_logo_url" => if(is_nil(bank_logo_url), do: S3Helper.get_imgix_url("assets/default_bank_logo.png"), else: S3Helper.get_imgix_url(bank_logo_url)),
        "branch_location" => branch_location,
        "display_sanctioned_amount" => Utils.format_money_new(sanctioned_amount),
        "sanctioned_amount" => sanctioned_amount,
        "is_editable" => is_editable
      },
      "disbursements" => disbursement
    }
  end

  def is_disbursement_editable(_processing_type, true), do: false

  def is_disbursement_editable(processing_type, _) do
    processing_type == "self"
  end

  def get_lead_next_action(lead, is_employee_view, is_employee, all_disbursements, add_detailed_response) when add_detailed_response == true do
    latest_disbursement = all_disbursements |> List.first()
    is_employee = if is_employee == true, do: true, else: false

    if not is_nil(latest_disbursement) do
      cond do
        is_nil(latest_disbursement.invoice_id) ->
          %{
            "open_history" => false,
            "action" => "raise_invoice",
            "invoice_url" => Map.get(latest_disbursement, :invoice_pdf_url),
            "disbursement_id" => Map.get(latest_disbursement, :disbursement_id),
            "otc_cleared" => Map.get(latest_disbursement, :otc_cleared),
            "pdd_cleared" => Map.get(latest_disbursement, :pdd_cleared),
            "loan_file_id" => Map.get(latest_disbursement, :loan_file_id)
          }

        latest_disbursement.invoice_status in ["approved_by_admin", "pending_from_super", "approved_by_super", "invoice_requested"] ->
          %{
            "open_history" => false,
            "action" => "no_action",
            "invoice_url" => Map.get(latest_disbursement, :invoice_pdf_url),
            "disbursement_id" => Map.get(latest_disbursement, :disbursement_id),
            "otc_cleared" => Map.get(latest_disbursement, :otc_cleared),
            "pdd_cleared" => Map.get(latest_disbursement, :pdd_cleared),
            "loan_file_id" => Map.get(latest_disbursement, :loan_file_id)
          }

        latest_disbursement.invoice_status in ["paid"] ->
          %{
            "open_history" => false,
            "action" => "no_action",
            "invoice_url" => Map.get(latest_disbursement, :invoice_pdf_url),
            "disbursement_id" => Map.get(latest_disbursement, :disbursement_id),
            "otc_cleared" => Map.get(latest_disbursement, :otc_cleared),
            "pdd_cleared" => Map.get(latest_disbursement, :pdd_cleared),
            "loan_file_id" => Map.get(latest_disbursement, :loan_file_id)
          }

        true ->
          %{
            "open_history" => true,
            "action" => "no_action",
            "invoice_url" => nil,
            "disbursement_id" => nil
          }
      end
    else
      action =
        cond do
          is_employee and not is_employee_view ->
            "no_action"

          is_employee and is_employee_view ->
            "contact_broker"

          lead.processing_type == Lead.self_processing_type() and not is_nil(lead.phone_number) ->
            "contact_lead"

          lead.processing_type == Lead.self_processing_type() and is_nil(lead.phone_number) ->
            "no_action"

          true ->
            "contact_support"
        end

      %{
        "channel_url" => lead.channel_url,
        "open_history" => false,
        "action" => action,
        "invoice_url" => nil,
        "invoice_number" => nil,
        "disbursement_id" => nil
      }
    end
  end

  def get_lead_next_action(lead, is_employee_view, is_employee, all_disbursements, add_detailed_response) when add_detailed_response == false do
    approved_invoices = all_disbursements |> Enum.filter(fn d -> d.invoice_status == "paid" end)
    unraised_invoice = all_disbursements |> Enum.filter(fn d -> is_nil(d.invoice_id) end)
    raised_invoices = all_disbursements |> Enum.filter(fn d -> not is_nil(d.invoice_id) end)
    is_employee = if is_employee == true, do: true, else: false

    unraised_invoice_count = length(unraised_invoice)
    approved_invoice_count = length(approved_invoices)
    raised_invoice_count = length(raised_invoices)

    if Status.get_status_from_id(lead.latest_lead_status.status_id)["identifier"] == "HOME_LOAN_DISBURSED" do
      approved_invoice = List.first(approved_invoices)
      raised_invoice = List.first(raised_invoices)

      cond do
        is_employee and is_employee_view ->
          %{
            "channel_url" => lead.channel_url,
            "action" => "contact_broker",
            "open_history" => false,
            "invoice_url" => nil,
            "disbursement_id" => nil
          }

        unraised_invoice_count >= 1 and approved_invoice_count >= 1 and Bank.get_commission_on_from_bank_name(raised_invoice.bank_name) == :sanctioned_amount ->
          %{
            "open_history" => all_disbursements > 1,
            "action" => "view_invoice",
            "invoice_url" => Map.get(raised_invoice, :invoice_pdf_url),
            "disbursement_id" => Map.get(raised_invoice, :disbursement_id),
            "otc_cleared" => Map.get(raised_invoice, :otc_cleared),
            "pdd_cleared" => Map.get(raised_invoice, :pdd_cleared),
            "loan_file_id" => Map.get(raised_invoice, :loan_file_id)
          }

        unraised_invoice_count >= 1 and raised_invoice_count >= 1 and Bank.get_commission_on_from_bank_name(raised_invoice.bank_name) == :sanctioned_amount ->
          %{
            "open_history" => all_disbursements > 1,
            "action" => if(is_employee and not is_employee_view, do: "no_action", else: "contact_support"),
            "invoice_url" => Map.get(raised_invoice, :invoice_pdf_url),
            "disbursement_id" => Map.get(raised_invoice, :disbursement_id),
            "otc_cleared" => Map.get(raised_invoice, :otc_cleared),
            "pdd_cleared" => Map.get(raised_invoice, :pdd_cleared),
            "loan_file_id" => Map.get(raised_invoice, :loan_file_id)
          }

        unraised_invoice_count >= 1 ->
          unraised_invoice = List.first(unraised_invoice)

          %{
            "open_history" => unraised_invoice_count > 1,
            "action" => "raise_invoice",
            "invoice_url" => nil,
            "disbursement_id" => Map.get(unraised_invoice, :disbursement_id),
            "otc_cleared" => Map.get(unraised_invoice, :otc_cleared),
            "pdd_cleared" => Map.get(unraised_invoice, :pdd_cleared),
            "loan_file_id" => Map.get(unraised_invoice, :loan_file_id)
          }

        approved_invoice_count >= 1 ->
          %{
            "open_history" => approved_invoice_count > 1,
            "action" => "view_invoice",
            "invoice_url" => Map.get(approved_invoice, :invoice_pdf_url),
            "disbursement_id" => Map.get(approved_invoice, :disbursement_id),
            "otc_cleared" => Map.get(approved_invoice, :otc_cleared),
            "pdd_cleared" => Map.get(approved_invoice, :pdd_cleared),
            "loan_file_id" => Map.get(approved_invoice, :loan_file_id)
          }

        true ->
          %{
            "open_history" => true,
            "action" => if(is_employee and not is_employee_view, do: "no_action", else: "contact_support"),
            "invoice_url" => nil,
            "disbursement_id" => nil
          }
      end
    else
      action =
        cond do
          is_employee and not is_employee_view ->
            "no_action"

          is_employee and is_employee_view ->
            "contact_broker"

          lead.processing_type == Lead.self_processing_type() and not is_nil(lead.phone_number) ->
            "contact_lead"

          lead.processing_type == Lead.self_processing_type() and is_nil(lead.phone_number) ->
            "no_action"

          true ->
            "contact_support"
        end

      %{
        "channel_url" => lead.channel_url,
        "open_history" => false,
        "action" => action,
        "invoice_url" => nil,
        "invoice_number" => nil,
        "disbursement_id" => nil
      }
    end
  end

  defp get_start_end_date(nil) do
    {nil, nil}
  end

  defp get_start_end_date("this_week") do
    datetime = Timex.now()
    {Timex.beginning_of_week(datetime, :mon), Timex.end_of_week(datetime, :mon)}
  end

  defp get_start_end_date("last_week") do
    datetime = Timex.now() |> Timex.shift(days: -7)
    {Timex.beginning_of_week(datetime, :mon), Timex.end_of_week(datetime, :mon)}
  end

  defp get_start_end_date("this_month") do
    datetime = Timex.now()
    {Timex.beginning_of_month(datetime), Timex.end_of_month(datetime)}
  end

  defp get_start_end_date("last_month") do
    %DateTime{day: day} = Timex.now()
    datetime = Timex.now() |> Timex.shift(days: -(day + 2))
    {Timex.beginning_of_month(datetime), Timex.end_of_month(datetime)}
  end

  defp get_start_end_date(_) do
    {nil, nil}
  end

  def maybe_remove_some_status(statuses, "V1"), do: statuses

  def maybe_remove_some_status(statuses, _version) do
    Enum.filter(statuses, fn {_status_id, data} ->
      data["active"] == true
    end)
  end

  defp get_lead_agg_data(city_id, duration_id, employee_credential_id, polygon_ids, access_city_ids, employee_role_id, version) do
    status_wise_lead_count =
      city_and_duration_polygon_filter_query(city_id, duration_id, polygon_ids, employee_credential_id, access_city_ids, employee_role_id)
      |> join(:inner, [l, b], ls in LeadStatus, on: l.latest_lead_status_id == ls.id)
      |> where([l, ..., ls], l.active == true)
      |> group_by([l, ..., ls], ls.status_id)
      |> select([l, ..., ls], {ls.status_id, count(l.id)})
      |> Repo.all()
      |> Enum.into(%{})

    status_list = if EmployeeRole.is_dsa_employee(employee_role_id), do: Status.status_list_for_dsa(), else: Status.status_list()

    broker_role_type_id =
      if Enum.member?([EmployeeRole.dsa_agent().id, EmployeeRole.dsa_admin().id, EmployeeRole.dsa_super().id], employee_role_id) do
        Broker.dsa()["id"]
      else
        Broker.real_estate_broker()["id"]
      end

    lead_agg_data =
      status_list
      |> maybe_remove_some_status(version)
      |> Enum.sort_by(&Map.get(elem(&1, 1), "order_for_employee_panel"))
      |> Enum.map(fn {status_id, data} ->
        %{
          "count" => status_wise_lead_count[status_id] || 0,
          "display_name" => data["display_name"],
          "status_identifier" => data["identifier"]
        }
      end)

    lead_status_data =
      lead_status_list()
      |> Enum.map(fn status ->
        %{
          "count" =>
            city_and_duration_polygon_filter_query(city_id, duration_id, polygon_ids, employee_credential_id, access_city_ids, employee_role_id)
            |> get_count_based_on_status(status, broker_role_type_id),
          "status" => status
        }
      end)

    {lead_agg_data, lead_status_data}
  end

  defp get_count_based_on_status(query, status, broker_role_type_id) do
    query
    |> join(:inner, [l, b], ls in LeadStatus, on: l.latest_lead_status_id == ls.id)
    |> append_query_based_on_status(status, broker_role_type_id)
    |> Repo.aggregate(:count, :id)
  end

  defp sorting_on_reminder_date(query, direction) do
    current_epoch_time = DateTime.utc_now() |> DateTime.to_unix()

    reminder_subquery =
      Reminder
      |> where([r], r.entity_type == ^Lead.homeloan_schema_name() and r.status_id == ^1 and r.reminder_date > ^current_epoch_time)
      |> group_by([r], r.entity_id)
      |> select([r], %{entity_id: r.entity_id, nearest_reminder_date: min(r.reminder_date)})

    query =
      query
      |> join(:left, [l, ..., ls], r in subquery(reminder_subquery), on: r.entity_id == l.id)
      |> select_merge([l, ..., r], map(r, ^~w(nearest_reminder_date)a))

    if direction,
      do: query |> order_by([l, ..., r], fragment("? asc, ? desc nulls last", r.nearest_reminder_date, l.inserted_at)),
      else: query |> order_by([l, ..., r], fragment("? desc, ? desc nulls last", r.nearest_reminder_date, l.inserted_at))
  end

  defp filter_leads(
         nil,
         _city_id,
         _duration_id,
         _employee_credential_id,
         _polygon_ids,
         _page_no,
         _append_employee_logs,
         _access_city_ids,
         nil,
         _order_by,
         _search_by_name_or_phone,
         _employee_role_id,
         _version
       ) do
    {:error, "Invalid status selected"}
  end

  defp filter_leads(
         status_id,
         city_id,
         duration_id,
         employee_credential_id,
         polygon_ids,
         page_no,
         append_employee_logs,
         access_city_ids,
         status,
         order_by,
         search_by_name_or_phone,
         employee_role_id,
         version
       ) do
    offset = (page_no - 1) * @homeloan_panel_page_limit

    query =
      city_and_duration_polygon_filter_query(city_id, duration_id, polygon_ids, employee_credential_id, access_city_ids, employee_role_id)
      |> join(:inner, [l, b], ls in LeadStatus, on: l.latest_lead_status_id == ls.id)

    query =
      if not is_nil(status_id) do
        where(query, [l, ..., ls], ls.status_id == ^status_id)
      else
        query
      end

    broker_role_type_id =
      if Enum.member?([EmployeeRole.dsa_agent().id, EmployeeRole.dsa_admin().id, EmployeeRole.dsa_super().id], employee_role_id) do
        Broker.dsa()["id"]
      else
        Broker.real_estate_broker()["id"]
      end

    # status can be active/closed/new
    query =
      if not is_nil(status) do
        append_query_based_on_status(query, status, broker_role_type_id)
      else
        query
      end

    query =
      if(not is_nil(search_by_name_or_phone) and search_by_name_or_phone != "") do
        name_query = "%#{String.downcase(search_by_name_or_phone) |> String.trim()}%"

        query
        |> join(:left, [l, b, ...], cr in Credential, on: cr.broker_id == b.id)
        |> where(
          [l, b, ..., cr],
          fragment("LOWER(?) LIKE ?", b.name, ^name_query) or fragment("LOWER(?) LIKE ?", l.name, ^name_query) or
            fragment("LOWER(?) LIKE ?", l.phone_number, ^name_query) or fragment("LOWER(?) LIKE ?", cr.phone_number, ^name_query)
        )
      else
        query
      end

    query =
      if(not is_nil(order_by) and not is_nil(order_by["key"]) and not is_nil(order_by["direction"]) and order_by["key"] != "" and order_by["direction"] != "") do
        key = order_by["key"]
        direction = if order_by["direction"] == "asc", do: true, else: false

        case key do
          "lead_name" ->
            if direction,
              do: query |> order_by([l, ..., ls], fragment("? asc nulls first", l.name)),
              else: query |> order_by([l, ..., ls], fragment("? desc nulls last", l.name))

          "loan_amount" ->
            if direction,
              do: query |> order_by([l, ..., ls], fragment("? asc nulls first", l.loan_amount)),
              else: query |> order_by([l, ..., ls], fragment("? desc nulls last", l.loan_amount))

          "broker_name" ->
            if direction,
              do: query |> order_by([l, b, ..., ls], fragment("? asc nulls first", b.name)),
              else: query |> order_by([l, b, ..., ls], fragment("? desc nulls last", b.name))

          "lead_created_at" ->
            if direction,
              do: query |> order_by([l, b, ..., ls], fragment("? asc nulls first", l.lead_creation_date)),
              else: query |> order_by([l, b, ..., ls], fragment("? desc nulls last", l.lead_creation_date))

          "reminder_date" ->
            query |> sorting_on_reminder_date(direction)

          _ ->
            query |> order_by([l, ..., ls], desc: l.inserted_at)
        end
      else
        case status do
          @active -> query |> sorting_on_reminder_date(true)
          _ -> query |> order_by([l, ..., ls], desc: l.inserted_at)
        end
      end

    total_result_count = query |> Repo.aggregate(:count, :id)

    result =
      query
      |> offset(^offset)
      |> limit(^@homeloan_panel_page_limit)
      |> Repo.all()
      |> Repo.preload([:country, :broker, :latest_lead_status, :employee_credentials, :homeloan_documents])
      |> Repo.preload(homeloan_lead_statuses: from(ls in LeadStatus, order_by: [desc: ls.inserted_at]))
      |> Enum.map(fn lead ->
        HomeloansPanel.create_lead_details_response_for_panel(lead, append_employee_logs, version)
      end)

    next_page_exists = length(result) == @homeloan_panel_page_limit

    status_list = if EmployeeRole.is_dsa_employee(employee_role_id), do: Status.status_list_for_dsa(), else: Status.status_list()

    status_list =
      status_list
      |> maybe_remove_some_status(version)
      |> Enum.sort_by(&Map.get(elem(&1, 1), "order_for_employee_panel"))
      |> Enum.map(fn {id, data} ->
        %{
          "is_selected" => status_id == id,
          "display_name" => data["display_name"],
          "status_identifier" => data["identifier"]
        }
      end)

    {:ok,
     %{
       "total_result_count" => total_result_count,
       "result" => result,
       "next_page_exists" => next_page_exists,
       "next_page_query_params" => "p=#{page_no + 1}",
       "status_list" => status_list,
       "bank_list" => Bank.get_all_bank_data()
     }}
  end

  defp append_query_based_on_status(query, nil, _broker_role_type_id), do: query

  defp append_query_based_on_status(query, status, broker_role_type_id) when broker_role_type_id == 2 do
    failed_status_id = Status.get_status_id_from_identifier("FAILED")
    homeloan_disbursed_status_id = Status.get_status_id_from_identifier("HOME_LOAN_DISBURSED")

    case status do
      @active ->
        called_lead_ids =
          Calls
          |> where([c], not is_nil(c.recording_url) and not is_nil(c.lead_id))
          |> distinct([c], c.lead_id)
          |> select([c], c.lead_id)
          |> Repo.all()

        query
        |> where([l, ..., ls], l.id in ^called_lead_ids)
        |> where([l, ..., ls], ls.status_id != ^failed_status_id or (ls.status_id != ^homeloan_disbursed_status_id and l.fully_disbursed in [false, nil]))
        |> distinct([l, ..., ls], l.id)

      @new ->
        sub_query =
          Lead
          |> join(:left, [l, ..., ls], cl in Calls, on: cl.lead_id == l.id)
          |> group_by([l], l.id)
          |> having([l, ..., cl], fragment("count(case when ? is null then NULL else 1 end) = 0", cl.recording_url))
          |> select([l], l.id)

        where(
          query,
          [l, ..., ls],
          l.id in subquery(sub_query) and (ls.status_id != ^failed_status_id or (ls.status_id != ^homeloan_disbursed_status_id and l.fully_disbursed == false))
        )

      @closed ->
        where(query, [l, ..., ls], (ls.status_id == ^homeloan_disbursed_status_id and l.fully_disbursed == true) or ls.status_id == ^failed_status_id)

      _ ->
        query
    end
  end

  defp append_query_based_on_status(query, status, broker_role_type_id) when broker_role_type_id == 1 do
    failed_status_id = Status.get_status_id_from_identifier("FAILED")
    commission_received_status_id = Status.get_status_id_from_identifier("COMMISSION_RECEIVED")

    case status do
      @active ->
        called_lead_ids =
          Calls
          |> where([c], not is_nil(c.recording_url) and not is_nil(c.lead_id))
          |> distinct([c], c.lead_id)
          |> select([c], c.lead_id)
          |> Repo.all()

        query
        |> where([l, ..., ls], l.id in ^called_lead_ids)
        |> where([l, ..., ls], ls.status_id not in ^[failed_status_id, commission_received_status_id])

      @new ->
        sub_query =
          Lead
          |> join(:left, [l, ..., ls], cl in Calls, on: cl.lead_id == l.id)
          |> group_by([l], l.id)
          |> having([l, ..., cl], fragment("count(case when ? is null then NULL else 1 end) = 0", cl.recording_url))
          |> select([l], l.id)

        where(query, [l, ..., ls], l.id in subquery(sub_query) and ls.status_id not in ^[failed_status_id, commission_received_status_id])

      @closed ->
        where(query, [l, ..., ls], ls.status_id in ^[failed_status_id, commission_received_status_id])

      _ ->
        query
    end
  end

  defp filter_leads(nil, _page_no, _employee_credential_id, _access_city_ids, _status, _employee_role_id, _version) do
    {:error, "phone number is mandatory"}
  end

  defp filter_leads(name_or_phone_number, page_no, employee_credential_id, access_city_ids, status, employee_role_id, version) do
    limit = 50
    offset = (page_no - 1) * limit
    name_query = "%#{String.downcase(name_or_phone_number)}%"

    broker_role_type_id =
      if Enum.member?([EmployeeRole.dsa_agent().id, EmployeeRole.dsa_admin().id, EmployeeRole.dsa_super().id], employee_role_id) do
        Broker.dsa()["id"]
      else
        Broker.real_estate_broker()["id"]
      end

    leads = Lead |> join(:inner, [l], b in Broker, on: l.broker_id == b.id and b.role_type_id == ^broker_role_type_id and l.active == true)

    leads =
      if broker_role_type_id == Broker.dsa()["id"] do
        ids = if EmployeeRole.dsa_agent().id == employee_role_id, do: [employee_credential_id], else: EmployeeCredential.get_reporter_ids(employee_credential_id)
        ids = if EmployeeRole.dsa_super().id == employee_role_id, do: EmployeeCredential.get_reporter_ids(ids), else: ids
        leads |> where([l], l.employee_credentials_id in ^ids)
      else
        leads
      end

    leads =
      if not is_nil(employee_credential_id) and broker_role_type_id != Broker.dsa()["id"] do
        leads |> where([l], l.employee_credentials_id == ^employee_credential_id)
      else
        leads
      end

    result =
      leads
      |> join(:left, [l, b], c in Credential, on: c.broker_id == b.id and c.active == true)
      |> where(
        [l, b, c],
        l.phone_number == ^name_or_phone_number or c.phone_number == ^name_or_phone_number or
          fragment("LOWER(?) LIKE ?", b.name, ^name_query) or fragment("LOWER(?) LIKE ?", l.name, ^name_query) or
          fragment("LOWER(?) LIKE ?", l.phone_number, ^name_query)
      )
      |> join(:inner, [l, ...], ls in LeadStatus, on: l.latest_lead_status_id == ls.id)
      |> append_query_based_on_status(status, broker_role_type_id)

    result =
      if not is_nil(access_city_ids) and access_city_ids |> length > 0 do
        result |> where([l], l.city_id in ^access_city_ids)
      else
        result
      end

    result =
      if is_nil(status) do
        order_by(result, [l, ..., ls], desc: ls.inserted_at)
      else
        order_by(result, [l, ..., ls, c], desc: ls.inserted_at)
      end

    result =
      result
      |> offset(^offset)
      |> limit(^limit)
      |> select([l, ...], l)
      |> Repo.all()
      |> Repo.preload([:country, :broker, :latest_lead_status, :employee_credentials, :homeloan_documents])
      |> Repo.preload(homeloan_lead_statuses: from(ls in LeadStatus, order_by: [desc: ls.inserted_at]))
      |> Enum.map(fn lead ->
        broker = lead.broker

        credential =
          Repo.all(from(c in Credential, where: c.broker_id == ^broker.id))
          |> List.first()

        credential = credential |> Repo.preload([:organization])
        broker = broker |> BnApis.Repo.preload([:polygon])

        status_timeline =
          lead.homeloan_lead_statuses
          |> Enum.map(&LeadStatus.get_details(&1, true))

        status_identifier =
          Status.status_list()
          |> get_in([lead.latest_lead_status.status_id, "identifier"])

        employee_creds =
          if not is_nil(lead.employee_credentials) do
            %{
              "name" => lead.employee_credentials.name,
              "phone_number" => lead.employee_credentials.phone_number,
              "id" => lead.employee_credentials.id,
              "uuid" => lead.employee_credentials.uuid
            }
          else
            %{}
          end

        polygon_name =
          case broker.polygon do
            %{name: name} ->
              name

            _ ->
              "Polygon not Present"
          end

        helpline_number = if is_nil(employee_creds["phone_number"]), do: @default_helpline_number, else: employee_creds["phone_number"]

        documents = Document.fetch_lead_docs(lead, _for_admin = true, false)

        %{
          "lead" => %{
            "id" => lead.id,
            "documents" => documents,
            "name" => lead.name,
            "city_id" => lead.city_id,
            "email" => lead.email_id,
            "remarks" => lead.remarks,
            "loan_amount" => lead.loan_amount,
            "helpline_number" => helpline_number,
            "phone_number" => "#{lead.country.country_code}-#{lead.phone_number}",
            "employment_type" => lead.employment_type,
            "status_identifier" => status_identifier,
            "consent_link" => ApplicationHelper.hosted_domain_url() <> "/hl/#{lead.external_link}",
            "status_timeline" =>
              status_timeline
              |> Enum.reduce([], fn lead_status, acc ->
                notes =
                  (lead_status["notes"] || [])
                  |> Enum.map(&Map.put(&1, "type", "notes"))

                status = %{
                  "text" => lead_status["description"],
                  "updated_at" => lead_status["updated_at"],
                  "type" => "status"
                }

                acc ++ notes ++ [status]
              end),
            "channel_url" => lead.channel_url,
            "created_at" => Time.naive_to_epoch(lead.inserted_at),
            "property_details" => %{
              "property_agreement_value" => lead.property_agreement_value,
              "property_all_inclusive_cost" => lead.property_all_inclusive_cost,
              "property_own_contribution" => lead.property_own_contribution,
              "property_type" => lead.property_type
            },
            "applicant_details" => %{
              "resident" => lead.resident,
              "gender" => lead.gender,
              "cibil_score" => lead.cibil_score,
              "date_of_birth" => lead.date_of_birth,
              "income_details" => lead.income_details,
              "additional_income" => lead.additional_income,
              "existing_loan_emi" => lead.existing_loan_emi
            },
            "additional_information" => %{
              "preferred_banks" => lead.preferred_banks,
              "is_finalised_property" => lead.is_finalised_property,
              "tentative_sanction_date" => lead.tentative_sanction_date,
              "is_roc_required" => lead.is_roc_required,
              "los_number" => lead.los_number,
              "any_case_lodged" => lead.any_case_lodged,
              "commission_percent" => lead.commission_percent,
              "loan_disbursed" => lead.loan_disbursed,
              "commission_disbursed" => lead.commission_disbursed
            },
            "nearest_reminders" => Reminder.get_nearest_reminders(lead.id, Lead.homeloan_schema_name())
          },
          "broker" => %{
            "name" => broker.name,
            "phone_number" => credential.phone_number,
            "organization" => credential.organization.name,
            "polygon" => polygon_name
          },
          "employee_assigned" => employee_creds,
          "processing_type" => lead.processing_type
        }
      end)

    next_page_exists = length(result) == limit

    status_list =
      Status.status_list()
      |> maybe_remove_some_status(version)
      |> Enum.sort_by(&Map.get(elem(&1, 1), "order_for_employee_panel"))
      |> Enum.map(fn {_id, data} ->
        %{
          "display_name" => data["display_name"],
          "status_identifier" => data["identifier"]
        }
      end)

    {:ok,
     %{
       "result" => result,
       "next_page_exists" => next_page_exists,
       "next_page_query_params" => "p=#{page_no + 1}",
       "status_list" => status_list,
       "bank_list" => Bank.get_all_bank_data()
     }}
  end

  defp city_and_duration_polygon_filter_query(
         city_id,
         duration_id,
         polygon_ids,
         employee_credential_id,
         access_city_ids,
         employee_role_id
       ) do
    {start_date, end_date} = get_start_end_date(duration_id)

    # DSA employess shall get dsa leads and hl employees shall get real estate broker leads
    broker_role_type_id =
      if Enum.member?([EmployeeRole.dsa_agent().id, EmployeeRole.dsa_admin().id, EmployeeRole.dsa_super().id], employee_role_id) do
        Broker.dsa()["id"]
      else
        Broker.real_estate_broker()["id"]
      end

    query = Lead |> join(:inner, [l], b in Broker, on: l.broker_id == b.id and b.role_type_id == ^broker_role_type_id and l.active == true)

    query =
      if broker_role_type_id == Broker.dsa()["id"] do
        ids = if EmployeeRole.dsa_agent().id == employee_role_id, do: [employee_credential_id], else: EmployeeCredential.get_reporter_ids(employee_credential_id)
        ids = if EmployeeRole.dsa_super().id == employee_role_id, do: EmployeeCredential.get_reporter_ids(ids), else: ids
        query |> where([l, b], l.employee_credentials_id in ^ids)
      else
        query
      end

    query =
      if is_nil(start_date),
        do: query,
        else: where(query, [l, b], l.inserted_at >= ^start_date)

    query =
      if is_nil(end_date),
        do: query,
        else: where(query, [l, b], l.inserted_at <= ^end_date)

    query =
      if is_nil(city_id) do
        query
      else
        query
        |> where([l, b], b.operating_city == ^city_id)
      end

    query =
      if is_nil(polygon_ids) do
        query
      else
        query
        |> where([l, b], b.polygon_id in ^polygon_ids)
      end

    query =
      if not is_nil(employee_credential_id) and broker_role_type_id != Broker.dsa()["id"] do
        query |> where([l], l.employee_credentials_id == ^employee_credential_id)
      else
        query
      end

    query =
      if not is_nil(access_city_ids) and access_city_ids |> length > 0 do
        query |> where([l, b], l.city_id in ^access_city_ids)
      else
        query
      end

    query
  end

  def mark_is_last_status_seen(lead_id) do
    Lead.mark_is_last_status_seen(lead_id, true)
  end

  def re_upload_documents(params) do
    doc_types = ["Bank Confirmation Proof", "Disbursement Letter", "Sanctioned Letter", "homeloan_documents"]

    if(not is_nil(params["doc_type_name"]) and params["doc_type_name"] in doc_types) do
      cond do
        params["doc_type_name"] == "Sanctioned Letter" ->
          if(not is_nil(params["loan_file_id"])) do
            loan_file = LoanFiles.get_loan_file(params["loan_file_id"])

            case loan_file do
              nil ->
                {:error, :not_found}

              loan_file ->
                LoanFiles.changeset(loan_file, %{
                  sanctioned_doc_url: params["document_url"]
                })
                |> Repo.update()
            end
          else
            {:error, "loan_file_id can't be blank"}
          end

        params["doc_type_name"] == "Bank Confirmation Proof" ->
          if(not is_nil(params["loan_disbursement_id"])) do
            disbursement = LoanDisbursement |> Repo.get_by(id: params["loan_disbursement_id"])

            case disbursement do
              nil ->
                {:error, "invalid loan_disbursement_id"}

              disbursement ->
                disbursement
                |> LoanDisbursement.changeset(%{otc_pdd_proof_doc: params["document_url"]})
                |> Repo.update()
            end
          else
            {:error, "loan_disbursement_id can't be blank"}
          end

        params["doc_type_name"] == "Disbursement Letter" ->
          if(not is_nil(params["loan_disbursement_id"])) do
            disbursement = LoanDisbursement |> Repo.get_by(id: params["loan_disbursement_id"])

            case disbursement do
              nil ->
                {:error, "invalid loan_disbursement_id"}

              disbursement ->
                disbursement
                |> LoanDisbursement.changeset(%{document_url: params["document_url"]})
                |> Repo.update()
            end
          else
            {:error, "loan_disbursement_id can't be blank"}
          end

        params["doc_type_name"] == "homeloan_documents" ->
          if(not is_nil(params["doc_id"])) do
            document = Document |> Repo.get_by(id: params["doc_id"])
            document |> Document.changeset(%{doc_url: params["document_url"]}) |> Repo.update()
          else
            {:error, "doc_id can't be blak"}
          end

        true ->
          {:error, "invalid doc_type"}
      end
    else
      {:error, "invalid doc_type"}
    end
  end
end
