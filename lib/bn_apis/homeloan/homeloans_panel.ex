defmodule BnApis.HomeloansPanel do
  import Ecto.Query

  alias BnApis.Repo
  alias BnApis.Homeloan.Lead
  alias BnApis.Homeloan.LeadStatus
  alias BnApis.Homeloan.Status
  alias BnApis.Accounts.Credential
  alias BnApis.Helpers.ApplicationHelper
  alias BnApis.Homeloan.Document
  alias BnApis.Reminder
  alias BnApis.Helpers.Time
  alias BnApis.Homeloan.LoanDisbursement
  alias BnApis.Homeloan.LoanFiles
  alias BnApis.Homeloan.Coapplicants
  alias BnApis.Homeloans
  alias BnApis.Homeloan.LeadStatusNote
  alias BnApis.Accounts.EmployeeCredential
  alias BnApis.Accounts.EmployeeRole
  alias BnApis.Organizations.Broker
  alias BnApis.AssignedBrokers
  alias BnApis.Homeloan.Bank

  @default_helpline_number "+918591340739"

  def get_lead_details(lead_id) do
    lead = Lead.get_homeloan_lead(lead_id)
    lead = Repo.preload(lead, [:broker, :homeloan_lead_statuses, :employee_credentials, :latest_lead_status, :homeloan_documents, :country, :loan_files])
    lead_details = create_lead_details_response_for_panel(lead, true, "V2")
    call_records = Lead.get_call_records_for_lead(lead_id)
    document_upload_history = Lead.get_document_upload_history(lead_id)
    timeline_data = create_timeline_data(call_records, document_upload_history, lead)
    status_changes = Lead.get_status_change_history(lead_id)
    loan_disbursements = LoanDisbursement.get_loan_disbursements(lead_id, false)

    {:ok,
     %{
       "timeline_data" => timeline_data,
       "status_changes" => status_changes,
       "loan_disbursements" => loan_disbursements,
       "lead_details" => lead_details
     }}
  end

  def create_timeline_data(call_records, document_upload_history, lead) do
    status_timeline = Homeloans.get_loan_file_status_timeline(lead, _for_panel = true)
    all_data = call_records ++ document_upload_history ++ status_timeline
    all_data = Enum.sort_by(all_data, & &1["inserted_at"], :desc)

    Enum.reduce(all_data, %{}, fn elem, acc ->
      status_id = elem["status_id"]
      status = Status.status_list()[status_id]["identifier"]
      val = Map.get(acc, status, [])
      Map.put(acc, status, val ++ [elem])
    end)
  end

  def create_lead_details_response_for_panel(lead, append_employee_logs, version \\ "V1") do
    broker = lead.broker

    credential =
      Repo.all(from(c in Credential, where: c.broker_id == ^broker.id))
      |> List.first()

    credential = credential |> Repo.preload([:organization])
    broker = broker |> Repo.preload([:polygon])

    polygon_name =
      case broker.polygon do
        %{name: name} ->
          name

        _ ->
          "Polygon not Present"
      end

    status_timeline =
      case version do
        "V1" ->
          lead.homeloan_lead_statuses
          |> Enum.map(&LeadStatus.get_details(&1, true, append_employee_logs, false))

        "V2" ->
          lead = lead |> Repo.preload(:loan_files)

          loan_file_statuses =
            Enum.reduce(lead.loan_files, [], fn loan_file, acc ->
              loan_file = loan_file |> Repo.preload(:loan_file_statuses)
              acc ++ loan_file.loan_file_statuses
            end)

          loan_file_statuses |> Enum.map(&LeadStatus.get_loan_file_details(&1, true, append_employee_logs))
      end

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

    helpline_number = if is_nil(employee_creds["phone_number"]), do: @default_helpline_number, else: employee_creds["phone_number"]

    %{
      "lead" => %{
        "id" => lead.id,
        "name" => lead.name,
        "city_id" => lead.city_id,
        "email" => lead.email_id,
        "documents" => Document.fetch_lead_docs(lead, _for_admin = true, false),
        "remarks" => lead.remarks,
        "loan_amount" => lead.loan_amount,
        "loan_type" => lead.loan_type,
        "helpline_number" => helpline_number,
        "phone_number" => "#{lead.country.country_code}-#{lead.phone_number}",
        "status_identifier" => status_identifier,
        "employment_type" => lead.employment_type,
        "consent_link" => ApplicationHelper.hosted_domain_url() <> "/hl/#{lead.external_link}",
        "bank_name" => lead.bank_name,
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
        "lead_creation_date" => if(lead.processing_type == Lead.bn_processing_type(), do: Time.naive_to_epoch_in_sec(lead.inserted_at), else: lead.lead_creation_date),
        "property_details" => %{
          "property_agreement_value" => lead.property_agreement_value,
          "property_all_inclusive_cost" => lead.property_all_inclusive_cost,
          "property_own_contribution" => lead.property_own_contribution,
          "property_type" => lead.property_type,
          "loan_amount_by_agent" => lead.loan_amount_by_agent,
          "property_stage" => lead.property_stage
        },
        "applicant_details" => %{
          "resident" => lead.resident,
          "gender" => lead.gender,
          "cibil_score" => lead.cibil_score,
          "date_of_birth" => lead.date_of_birth,
          "income_details" => lead.income_details,
          "additional_income" => lead.additional_income,
          "existing_loan_emi" => lead.existing_loan_emi,
          "pan" => lead.pan
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
          "commission_disbursed" => lead.commission_disbursed,
          "loan_subtype" => lead.loan_subtype
        },
        "nearest_reminders" => Reminder.get_nearest_reminders(lead.id, Lead.homeloan_schema_name()),
        "processing_type" => lead.processing_type,
        "loan_files" => LoanFiles.get_loan_files(lead.id),
        "coapplicants_details" => Coapplicants.get_coapplicants_for_lead(lead.id),
        "sanctioned_amount" => lead.sanctioned_amount,
        "notes" => LeadStatusNote.get_notes_by_lead_id(lead.id)
      },
      "broker" => %{
        "name" => broker.name,
        "phone_number" => credential.phone_number,
        "organization" => credential.organization.name,
        "polygon" => polygon_name
      },
      "employee_assigned" => employee_creds,
      "loan_files_docs" => Lead.get_loan_files_docs(lead.id, "V2")
    }
  end

  defp total_amount(all_leads, key), do: all_leads |> Enum.reduce(0, fn lead, acc -> acc + (lead[key] || 0) end)

  def get_all_leads_for_employee_view(user_id, params, add_pagination \\ true) do
    page_no = params["p"] || 1
    size = params["size"] || 20
    emp_uuids = EmployeeCredential.get_all_assigned_employee(user_id, params["q"])

    emp_uuids =
      if(is_list(params["employee_uuids"]) and params["employee_uuids"] not in [[], nil]) do
        emp_uuids |> Enum.filter(fn uuid -> uuid in params["employee_uuids"] end)
      else
        emp_uuids
      end

    agent_lead_details =
      emp_uuids
      |> Enum.map(fn uuid ->
        cred = EmployeeCredential |> Repo.get_by(uuid: uuid, active: true)
        params = Map.delete(params, "q")
        all_leads_for_employee = get_lead_for_panel_view(cred.id, params, "employee", false)
        all_leads_details = all_leads_for_employee |> Map.get("leads")
        {has_reportees, no_of_reportees} = EmployeeCredential.check_for_user_reportees(cred.id)

        %{
          "name" => cred.name,
          "id" => cred.id,
          "user_type" => "employee",
          "total_sanctioned_amt" => total_amount(all_leads_details, "sanctioned_amount"),
          "total_disbursed_amt" => total_amount(all_leads_details, "total_disbursed_amt"),
          "total_commission_amt" => total_amount(all_leads_details, "total_commission_amt"),
          "net_revenue" => total_amount(all_leads_details, "total_disbursed_amt") - total_amount(all_leads_details, "total_commission_amt"),
          "unbilled_amt" => nil,
          "billed_amt" => nil,
          "lead_count" => length(all_leads_details),
          "is_user_has_reportees" => has_reportees,
          "no_of_reportees" => no_of_reportees
        }
      end)

    agent_lead_details =
      if(not is_nil(params["q"]) and params["q"] != "") do
        formatted_string = String.downcase(String.trim(params["q"]))
        agent_lead_details |> Enum.filter(fn res -> String.contains?(String.downcase(res["name"]), formatted_string) end)
      else
        agent_lead_details
      end

    sorted_response =
      if(
        not is_nil(params["order_by"]) and not is_nil(params["order_by"]["key"]) and not is_nil(params["order_by"]["direction"]) and params["order_by"]["key"] != "" and
          params["order_by"]["direction"] != ""
      ) do
        key = params["order_by"]["key"]
        flag = if params["order_by"]["direction"] == "desc", do: :desc, else: :asc

        case key do
          "disbursed_amt" -> Enum.sort_by(agent_lead_details, & &1["total_disbursed_amt"], flag)
          "commission_amt" -> Enum.sort_by(agent_lead_details, & &1["total_commission_amt"], flag)
          "sanctioned_amt" -> Enum.sort_by(agent_lead_details, & &1["total_sanctioned_amt"], flag)
          "net_revenue" -> Enum.sort_by(agent_lead_details, & &1["net_revenue"], flag)
          "name" -> Enum.sort_by(agent_lead_details, & &1["name"], flag)
          "lead_count" -> Enum.sort_by(agent_lead_details, & &1["lead_count"], flag)
          _ -> agent_lead_details
        end
      else
        agent_lead_details
      end

    sorted_response =
      if(add_pagination) do
        sorted_response |> Enum.drop(size * (page_no - 1)) |> Enum.take(size)
      else
        sorted_response
      end

    %{
      "has_more" => page_no < Float.ceil(length(agent_lead_details) / size),
      "total_count" => length(agent_lead_details),
      "next_page_query_params" => "p=#{page_no + 1}",
      "overall_disbursed_amt" => total_amount(agent_lead_details, "total_disbursed_amt"),
      "overall_commission_amt" => total_amount(agent_lead_details, "total_commission_amt"),
      "overall_sanctioned_amt" => total_amount(agent_lead_details, "total_sanctioned_amt"),
      "overall_net_revenue" => total_amount(agent_lead_details, "net_revenue"),
      "details" => sorted_response
    }
  end

  def get_all_leads_for_dsa_view(user_id, params) do
    page_no = Map.get(params, "p", 1)
    size = Map.get(params, "size", 20)

    employee = EmployeeCredential |> Repo.get_by(id: user_id)

    dsa_ids =
      if(employee.employee_role_id == EmployeeRole.super().id) do
        get_all_dsa_super_usr(params["q"])
      else
        get_all_assiged_user_info(user_id, params["q"])
      end

    all_assigned_dsa =
      dsa_ids
      |> Enum.map(fn broker_id ->
        get_all_leads_for_dsa_user(broker_id, params)
      end)

    sorted_response =
      if(
        not is_nil(params["order_by"]) and not is_nil(params["order_by"]["key"]) and not is_nil(params["order_by"]["direction"]) and params["order_by"]["key"] != "" and
          params["order_by"]["direction"] != ""
      ) do
        key = params["order_by"]["key"]
        flag = if params["order_by"]["direction"] == "desc", do: :desc, else: :asc

        case key do
          "disbursed_amt" -> Enum.sort_by(all_assigned_dsa, & &1["total_disbursed_amt"], flag)
          "commission_amt" -> Enum.sort_by(all_assigned_dsa, & &1["total_commission_amt"], flag)
          "sanctioned_amt" -> Enum.sort_by(all_assigned_dsa, & &1["total_sanctioned_amt"], flag)
          "net_revenue" -> Enum.sort_by(all_assigned_dsa, & &1["net_revenue"], flag)
          "name" -> Enum.sort_by(all_assigned_dsa, & &1["name"], flag)
          "lead_count" -> Enum.sort_by(all_assigned_dsa, & &1["lead_count"], flag)
          _ -> all_assigned_dsa
        end
      else
        all_assigned_dsa
      end

    total_count = length(all_assigned_dsa)
    next_page_exists = page_no < Float.ceil(total_count / size)
    sorted_response = sorted_response |> Enum.drop(size * (page_no - 1)) |> Enum.take(size)

    %{
      "has_more" => next_page_exists,
      "total_count" => total_count,
      "next_page_query_params" => "p=#{page_no + 1}",
      "overall_disbursed_amt" => total_amount(all_assigned_dsa, "total_disbursed_amt"),
      "overall_commission_amt" => total_amount(all_assigned_dsa, "total_commission_amt"),
      "overall_sanctioned_amt" => total_amount(all_assigned_dsa, "total_sanctioned_amt"),
      "overall_net_revenue" => total_amount(all_assigned_dsa, "net_revenue"),
      "details" => sorted_response
    }
  end

  def get_all_leads_for_dsa_user(broker_id, params) do
    dsa_status_ids = Status.dsa_dashboard_status_ids()

    query =
      Lead
      |> join(:inner, [l], b in Broker, on: l.broker_id == b.id and b.role_type_id == ^Broker.dsa()["id"])
      |> join(:inner, [l, b], cred in Credential, on: cred.broker_id == b.id and cred.active == true)
      |> join(:inner, [l, b, cred], ls in LeadStatus, on: ls.id == l.latest_lead_status_id)
      |> where([l, b, cred, ls], ls.status_id in ^dsa_status_ids and b.id == ^broker_id and l.active == true)

    query =
      if(not is_nil(params["bank_ids"]) and length(params["bank_ids"]) > 0) do
        bank_sub_query = sub_query_bank_loan_files(params["bank_ids"])

        query
        |> join(:inner, [l, b, cred, ls], hb in subquery(bank_sub_query), on: l.id == hb.homeloan_lead_id)
        |> where([l, b, cred, ls, hb], fragment("? :: integer[] && ?", hb.bank_ids, ^params["bank_ids"]))
      else
        query
      end

    query =
      if(not is_nil(params["loan_types"]) and length(params["loan_types"]) > 0) do
        loan_types = params["loan_types"] |> Enum.map(&String.downcase(&1))
        query |> where([l, b, cred, ls], fragment("LOWER(?) = ANY(?)", l.loan_type, ^loan_types))
      else
        query
      end

    query =
      if(not is_nil(params["status_identifier"]) and params["status_identifier"] != "") do
        status_id = Status.get_status_id_from_identifier(params["status_identifier"])
        query |> where([l, b, cred, ls], ls.status_id == ^status_id)
      else
        query
      end

    query = create_date_filter(query, params["date_filter"])

    leads =
      query
      |> preload([:latest_lead_status])
      |> Repo.all()
      |> Enum.map(fn lead -> get_params(lead) end)

    broker = Repo.get_by(Broker, id: broker_id)

    %{
      "name" => broker.name,
      "id" => broker.id,
      "user_type" => "broker",
      "lead_count" => length(leads),
      "total_sanctioned_amt" => total_amount(leads, "sanctioned_amount"),
      "total_disbursed_amt" => total_amount(leads, "total_disbursed_amt"),
      "total_commission_amt" => total_amount(leads, "total_commission_amt"),
      "net_revenue" => total_amount(leads, "total_disbursed_amt") - total_amount(leads, "total_commission_amt")
    }
  end

  defp get_params(lead) do
    broker = Broker.fetch_broker_from_id(lead.broker_id)
    credential = Credential.get_credential_from_broker_id(lead.broker_id)
    loan_files = LoanFiles.get_loan_files(lead.id, false)

    %{
      "broker_id" => broker.id,
      "broker_name" => broker.name,
      "broker_contact_number" => "XXXXXX" <> String.slice(credential.phone_number, -4..-1),
      "broker_country_code" => credential.country_code,
      "lead_id" => lead.id,
      "customer_name" => lead.name,
      "loan_amount" => lead.loan_amount,
      "current_status" => %{
        "status_name" => Status.get_status_from_id(lead.latest_lead_status.status_id)["display_name"],
        "status_identifier" => Status.get_status_from_id(lead.latest_lead_status.status_id)["identifier"],
        "status_id" => lead.latest_lead_status.status_id,
        "updated_at" => lead.latest_lead_status.updated_at,
        "updated_at_unix" => Time.naive_to_epoch_in_sec(lead.latest_lead_status.updated_at),
        "bg_color_code" => Status.get_status_from_id(lead.latest_lead_status.status_id)["bg_color_code"],
        "text_color_code" => Status.get_status_from_id(lead.latest_lead_status.status_id)["text_color_code"]
      },
      "display_loan_amount" => lead.loan_amount,
      "lead_creation_date" => lead.lead_creation_date,
      "loan_type" => lead.loan_type,
      "bank_name" => lead.bank_name,
      "branch_name" => lead.branch_name,
      "fully_disbursed" => lead.fully_disbursed,
      "loan_subtype" => lead.loan_subtype,
      "processing_type" => lead.processing_type,
      "loan_files" => loan_files
    }
    |> Map.merge(add_disburse_and_comission_amt(loan_files))
  end

  defp create_date_filter(query, date_filter) when is_list(date_filter) and length(date_filter) == 2 do
    start_date = DateTime.from_unix!(List.first(date_filter))
    end_date = DateTime.from_unix!(List.last(date_filter))

    query
    |> where(
      [l, ...],
      fragment(
        "(? BETWEEN ? AND ? AND ? ilike ?) or (? BETWEEN ? AND ? AND ? ilike ?)",
        l.lead_creation_date,
        ^List.first(date_filter),
        ^List.last(date_filter),
        l.processing_type,
        ^Lead.self_processing_type(),
        l.inserted_at,
        ^start_date,
        ^end_date,
        l.processing_type,
        ^Lead.bn_processing_type()
      )
    )
  end

  defp create_date_filter(query, _date_filter), do: query

  defp add_disburse_and_comission_amt(loan_files) do
    loan_disbursed_files = loan_files |> Enum.filter(fn x -> not is_nil(x.disbursements) and length(x.disbursements) > 0 end)

    if(loan_disbursed_files not in [nil, []]) do
      commissioned_loan_file = loan_disbursed_files |> Enum.find(fn x -> not is_nil(x.total_commission_amt) and x.total_commission_amt > 0 end)

      commissioned_loan_file =
        if is_nil(commissioned_loan_file) do
          List.first(loan_disbursed_files)
        else
          commissioned_loan_file
        end

      %{
        "total_disbursed_amt" => commissioned_loan_file.total_disbursed_amt,
        "total_commission_amt" => commissioned_loan_file.total_commission_amt,
        "sanctioned_amount" => commissioned_loan_file.sanctioned_amount
      }
    else
      max_sacntioned_amt =
        if(length(loan_files) > 0) do
          loan_files
          |> Enum.map(&(&1.sanctioned_amount || 0))
          |> Enum.max()
        else
          nil
        end

      %{
        "total_disbursed_amt" => nil,
        "total_commission_amt" => nil,
        "sanctioned_amount" => max_sacntioned_amt
      }
    end
  end

  defp get_query_for_loan_files() do
    distinct_loan_disbursement =
      LoanDisbursement
      |> where([ld], ld.active == true)
      |> group_by([ld], [ld.loan_file_id])
      |> select([ld], %{loan_file_id: ld.loan_file_id, total_disbursed_amt: max(ld.loan_disbursed), total_commission_amt: max(ld.loan_commission)})

    LoanFiles
    |> join(:left, [lf], ld in subquery(distinct_loan_disbursement), on: ld.loan_file_id == lf.id)
    |> where([lf, ld], lf.active == ^true)
    |> group_by([lf, ld], [lf.homeloan_lead_id])
    |> select([lf, ld], %{
      homeloan_lead_id: lf.homeloan_lead_id,
      sanctioned_amount: max(lf.sanctioned_amount),
      total_disbursed_amt: avg(ld.total_disbursed_amt),
      total_commission_amt: avg(ld.total_commission_amt)
    })
  end

  defp sub_query_bank_loan_files(bank_ids) do
    bank_names = Bank.get_bank_data(bank_ids) |> Enum.map(& &1.name)

    loan_file_query =
      LoanFiles
      |> where([lf], lf.active == true and lf.bank_id in ^bank_ids)
      |> select([lf], %{homeloan_lead_id: lf.homeloan_lead_id, bank_id: lf.bank_id})

    Lead
    |> join(:inner, [l], ba in Bank, on: ba.name == l.bank_name and ba.active == true)
    |> where([l, ba], l.active == true and l.bank_name in ^bank_names)
    |> select([l, ba], %{homeloan_lead_id: l.id, bank_id: ba.id})
    |> union(^loan_file_query)
    |> subquery()
    |> group_by([s], s.homeloan_lead_id)
    |> select([s], %{homeloan_lead_id: s.homeloan_lead_id, bank_ids: fragment("array_agg(?)", s.bank_id)})
  end

  defp get_lead_count_by_status_id(query, status_id) do
    query
    |> where([l, b, cred, ls, lf], ls.status_id == ^status_id)
    |> distinct(:id)
    |> Repo.aggregate(:count, :id)
  end

  def get_lead_for_panel_view(user_id, params, user_type, add_pagination \\ true) do
    page_no = Map.get(params, "p", 1)
    size = Map.get(params, "size", 20)
    dsa_status_ids = Status.dsa_dashboard_status_ids()
    loan_files_query = get_query_for_loan_files()

    query =
      Lead
      |> join(:inner, [l], b in Broker, on: l.broker_id == b.id and b.role_type_id == ^Broker.dsa()["id"] and b.hl_commission_status == ^Broker.approved()["id"])
      |> join(:inner, [l, b], cred in Credential, on: cred.broker_id == b.id and cred.active == true)
      |> join(:inner, [l, b, cred], ls in LeadStatus, on: ls.id == l.latest_lead_status_id)
      |> join(:left, [l, b, cred, ls], lf in subquery(loan_files_query), on: lf.homeloan_lead_id == l.id)
      |> where([l, b, cred, ls], l.active == true)
      |> select_merge([l, b, cred, ls, lf], %{
        total_disbursed_amt: lf.total_disbursed_amt,
        total_commission_amt: lf.total_commission_amt,
        total_sanctioned_amt: lf.sanctioned_amount
      })
      |> where([l, b, cred, ls, lf], ls.status_id in ^dsa_status_ids)

    query =
      if(not is_nil(params["loan_types"]) and length(params["loan_types"]) > 0) do
        loan_types = params["loan_types"] |> Enum.map(&String.downcase(&1))
        query |> where([l, b, cred, ls, lf], fragment("LOWER(?) = ANY(?)", l.loan_type, ^loan_types))
      else
        query
      end

    query = create_date_filter(query, params["date_filter"])

    query =
      if(not is_nil(params["q"]) and params["q"] != "") do
        formatted_query = "%#{String.downcase(String.trim(params["q"]))}%"
        query |> where([l, b, cred, ls, lf], fragment("LOWER(?) LIKE ?", l.name, ^formatted_query))
      else
        query
      end

    query =
      case user_type do
        "broker" ->
          query |> where([l, b, cred, ls, lf], b.id == ^user_id and b.hl_commission_status == ^Broker.approved()["id"])

        _ ->
          dsa_ids = get_all_assiged_user_info(user_id)
          query |> where([l, b, ...], b.id in ^dsa_ids)
      end

    query =
      if(not is_nil(params["bank_ids"]) and length(params["bank_ids"]) > 0) do
        bank_sub_query = sub_query_bank_loan_files(params["bank_ids"])

        query
        |> join(:inner, [l, b, cred, ls, lf], hb in subquery(bank_sub_query), on: l.id == hb.homeloan_lead_id)
        |> where([l, b, cred, ls, lf, hb], fragment("? :: integer[] && ?", hb.bank_ids, ^params["bank_ids"]))
      else
        query
      end

    created_leads_count = get_lead_count_by_status_id(query, 9)
    logged_in_leads_count = get_lead_count_by_status_id(query, 4)
    sanctioned_leads_count = get_lead_count_by_status_id(query, 15)
    rejected_leads_count = get_lead_count_by_status_id(query, 8)
    disbursed_leads_count = get_lead_count_by_status_id(query, 6)

    query =
      if(not is_nil(params["status_identifier"]) and params["status_identifier"] != "") do
        status_id = Status.get_status_id_from_identifier(params["status_identifier"])
        query |> where([l, b, cred, ls, lf], ls.status_id == ^status_id)
      else
        query
      end

    query =
      if(
        not is_nil(params["order_by"]) and not is_nil(params["order_by"]["key"]) and not is_nil(params["order_by"]["direction"]) and params["order_by"]["key"] != "" and
          params["order_by"]["direction"] != ""
      ) do
        key = params["order_by"]["key"]
        direction = if params["order_by"]["direction"] == "asc", do: true, else: false

        case direction do
          true ->
            case key do
              "disbursed_amt" -> query |> order_by([l, b, cred, ls, lf], fragment("? asc nulls first", lf.total_disbursed_amt))
              "commission_amt" -> query |> order_by([l, b, cred, ls, lf], fragment("? asc nulls first", lf.total_commission_amt))
              "sanctioned_amt" -> query |> order_by([l, b, cred, ls, lf], fragment("? asc nulls first", lf.sanctioned_amount))
              "lead_name" -> query |> order_by([l, b, cred, ls, lf], fragment("? asc nulls first", l.name))
              _ -> query
            end

          false ->
            case key do
              "disbursed_amt" -> query |> order_by([l, b, cred, ls, lf], fragment("? desc nulls last", lf.total_disbursed_amt))
              "commission_amt" -> query |> order_by([l, b, cred, ls, lf], fragment("? desc nulls last", lf.total_commission_amt))
              "sanctioned_amt" -> query |> order_by([l, b, cred, ls, lf], fragment("? desc nulls last", lf.sanctioned_amount))
              "lead_name" -> query |> order_by([l, b, cred, ls, lf], fragment("? desc nulls last", l.name))
              _ -> query
            end
        end
      else
        query
      end

    total_count = query |> distinct(:id) |> Repo.aggregate(:count, :id)
    next_page_exists = page_no < Float.ceil(total_count / size)

    query =
      if(add_pagination) do
        query |> limit(^size) |> offset(^((page_no - 1) * size))
      else
        query
      end

    leads =
      query
      |> preload(:latest_lead_status)
      |> Repo.all()
      |> Enum.map(fn lead -> get_params(lead) end)

    %{
      "leads" => leads,
      "has_more" => next_page_exists,
      "total_count" => created_leads_count + logged_in_leads_count + sanctioned_leads_count + rejected_leads_count + disbursed_leads_count,
      "next_page_query_params" => "p=#{page_no + 1}",
      "created_leads_count" => created_leads_count,
      "logged_in_leads_count" => logged_in_leads_count,
      "sanctioned_leads_count" => sanctioned_leads_count,
      "rejected_leads_count" => rejected_leads_count,
      "disbursed_leads_count" => disbursed_leads_count
    }
  end

  def get_all_assiged_user_info(user_id, q \\ nil) do
    reporting_emp_ids = EmployeeCredential.get_all_assigned_employee_for_an_employee(user_id) |> Enum.uniq()
    get_all_assigned_dsa_users(reporting_emp_ids ++ [user_id], q) |> Enum.uniq()
  end

  def get_all_assigned_dsa_users(employee_ids, search_text) do
    query =
      AssignedBrokers
      |> join(:inner, [a], e in EmployeeCredential, on: a.employees_credentials_id == e.id and a.active == true)
      |> join(:inner, [a, e], b in Broker, on: b.role_type_id == ^Broker.dsa()["id"] and b.hl_commission_status == ^Broker.approved()["id"])
      |> where([a, e, b], e.id in ^employee_ids and e.active == true)

    query =
      if(search_text not in [nil, ""]) do
        formatted_query = "%#{String.downcase(String.trim(search_text))}%"
        query |> where([a, e, b], fragment("LOWER(?) LIKE ?", b.name, ^formatted_query))
      else
        query
      end

    query
    |> select([a, e, b], a.broker_id)
    |> distinct([b], b.id)
    |> Repo.all()
  end

  def get_all_dsa_super_usr(search_text) do
    query =
      Broker
      |> where([b], b.role_type_id == ^Broker.dsa()["id"] and b.hl_commission_status == ^Broker.approved()["id"])

    query =
      if(search_text not in [nil, ""]) do
        formatted_query = "#{String.downcase(String.trim(search_text))}%"
        query |> where([b], fragment("LOWER(?) LIKE ?", b.name, ^formatted_query))
      else
        query
      end

    query
    |> select([b], b.id)
    |> Repo.all()
  end
end
