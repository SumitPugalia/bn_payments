defmodule BnApis.Homeloan.Lead do
  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query

  alias BnApis.Repo
  alias BnApis.Homeloan.Lead
  alias BnApis.Organizations.Broker
  alias BnApis.Organizations.Organization
  alias BnApis.Homeloan.LeadStatus
  alias BnApis.Homeloan.Country
  alias BnApis.Helpers.EntroyHelper
  alias BnApis.Accounts.EmployeeCredential
  alias BnApis.Accounts.EmployeeRole
  alias BnApis.Homeloan.Document
  alias BnApis.CreateHLSendbirdChannel
  alias BnApis.Helpers.AuditedRepo
  alias BnApis.Calls
  alias BnApis.Homeloan.HLCallLeadStatus
  alias BnApis.Helpers.Time
  alias BnApis.Homeloan.LoanDisbursement
  alias BnApis.Homeloan.DocType
  alias BnApis.Helpers.S3Helper
  alias BnApis.Homeloan.LoanDisbursement
  alias BnApis.Accounts.Credential
  alias BnApis.Homeloan.LoanFiles
  alias BnApis.AssignedBrokers

  schema "homeloan_leads" do
    field(:name, :string)
    field(:uuid, Ecto.UUID, read_after_writes: true)
    field(:phone_number, :string)
    field(:external_link, :string)
    field(:lead_squared_uuid, :string)
    field(:loan_amount, :integer)
    field(:remarks, :string)
    field(:docs, {:array, :map}, default: [])
    field(:city_id, :integer)
    field(:employment_type, :integer)
    field(:channel_url, :string)
    field(:email_id, :string)
    field(:is_last_status_seen, :boolean, default: false)

    field(:property_agreement_value, :integer)
    field(:property_all_inclusive_cost, :integer)
    field(:property_own_contribution, :integer)
    field(:property_type, :string)
    field(:resident, :string)
    field(:gender, :string)
    field(:cibil_score, :float)
    field(:date_of_birth, :integer)
    field(:income_details, :integer)
    field(:additional_income, :integer)
    field(:existing_loan_emi, :integer)
    field(:preferred_banks, {:array, :string}, default: [])
    field(:is_finalised_property, :boolean, default: false)
    field(:tentative_sanction_date, :integer)
    field(:is_roc_required, :boolean, default: false)
    field(:los_number, :integer)
    field(:any_case_lodged, :boolean, default: false)
    field(:commission_percent, :float)
    field(:loan_disbursed, :integer)
    field(:commission_disbursed, :integer)

    field(:lead_creation_date, :integer)
    field(:bank_name, :string)
    field(:branch_name, :string)
    field(:fully_disbursed, :boolean, default: false)
    field(:loan_type, :string)
    field(:property_stage, :string)
    field(:processing_type, :string)
    field(:application_id, :string)
    field(:bank_rm, :string)
    field(:bank_rm_phone_number, :string)
    field(:sanctioned_amount, :integer)
    field(:rejected_lost_reason, :string)
    field(:rejected_doc_url, :string)
    field(:sanctioned_doc_url, :string)
    field(:loan_subtype, :string)
    field(:pan, :string)
    field(:loan_amount_by_agent, :integer)
    field(:active, :boolean, default: true)
    field(:nearest_reminder_date, :integer, virtual: true)
    field(:total_disbursed_amt, :integer, virtual: true)
    field(:total_commission_amt, :integer, virtual: true)
    field(:total_sanctioned_amt, :integer, virtual: true)

    belongs_to(:country, Country)

    belongs_to(:latest_lead_status, LeadStatus,
      foreign_key: :latest_lead_status_id,
      references: :id
    )

    belongs_to(:old_broker, Broker)
    belongs_to(:old_organization, Organization)

    has_many(:homeloan_documents, Document, foreign_key: :homeloan_lead_id)

    belongs_to(:broker, Broker)
    belongs_to :employee_credentials, EmployeeCredential

    has_many(:homeloan_lead_statuses, LeadStatus, foreign_key: :homeloan_lead_id)
    has_many(:loan_files, LoanFiles, foreign_key: :homeloan_lead_id)

    has_many(:loan_disbursements, LoanDisbursement, foreign_key: :homeloan_lead_id)

    timestamps()
  end

  @required [:name, :country_id, :broker_id, :external_link, :old_broker_id, :old_organization_id]

  @optional [
    :phone_number,
    :docs,
    :lead_squared_uuid,
    :employee_credentials_id,
    :remarks,
    :loan_amount,
    :city_id,
    :employment_type,
    :channel_url,
    :is_last_status_seen,
    :property_agreement_value,
    :property_all_inclusive_cost,
    :property_own_contribution,
    :property_type,
    :resident,
    :gender,
    :cibil_score,
    :date_of_birth,
    :income_details,
    :additional_income,
    :existing_loan_emi,
    :preferred_banks,
    :is_finalised_property,
    :tentative_sanction_date,
    :is_roc_required,
    :los_number,
    :any_case_lodged,
    :commission_percent,
    :loan_disbursed,
    :commission_disbursed,
    :email_id,
    :lead_creation_date,
    :bank_name,
    :branch_name,
    :fully_disbursed,
    :loan_type,
    :property_stage,
    :processing_type,
    :application_id,
    :bank_rm,
    :bank_rm_phone_number,
    :sanctioned_amount,
    :rejected_lost_reason,
    :rejected_doc_url,
    :sanctioned_doc_url,
    :loan_subtype,
    :loan_amount_by_agent,
    :pan,
    :active
  ]

  @loan_types ["Home Loan", "Commercial loan (LAP/LRD)", "Business loan", "Working Capital loan", "Personal loan", "Education Loan", "Car Loan", "Connector"]
  @property_types ["Residential", "Commercial", "Industrial", "Plot"]
  @property_stages ["Ready to move", "Under construction"]
  @self_processing_type "self"
  @bn_processing_type "bn"

  def self_processing_type(), do: @self_processing_type
  def bn_processing_type(), do: @bn_processing_type

  def loan_types(), do: @loan_types
  def property_types(), do: @property_types
  def property_stages(), do: @property_stages

  @homeloan_schema_name "homeloan_leads"
  @doc false
  def changeset(lead, attrs) do
    lead
    |> cast(attrs, @required ++ @optional)
    |> validate_required(@required)
    |> foreign_key_constraint(:country_id)
    |> foreign_key_constraint(:latest_lead_status_id)
    |> foreign_key_constraint(:broker_id)
    |> unique_constraint(:unique_homeloan_leads,
      name: :unique_phone_number_pan_loan_type_active_leads,
      message: "A active Lead with same phone number, pan and loan_type exists."
    )
  end

  def latest_lead_status_changeset(lead, attrs) do
    lead
    |> cast(attrs, [:latest_lead_status_id])
    |> validate_required([:latest_lead_status_id])
    |> foreign_key_constraint(:country_id)
    |> foreign_key_constraint(:latest_lead_status_id)
    |> foreign_key_constraint(:broker_id)
  end

  def docs_changeset(lead, attrs) do
    lead
    |> cast(attrs, [:docs])
  end

  def homeloan_schema_name do
    @homeloan_schema_name
  end

  def get_homeloan_lead(id) do
    Repo.get_by(Lead, id: id)
  end

  def create_lead!(
        phone_number,
        country_id,
        name,
        remarks,
        broker_id,
        loan_amount,
        employment_type,
        lead_creation_date,
        bank_name,
        branch_name,
        loan_type,
        property_stage,
        property_type,
        processing_type,
        pan,
        loan_subtype
      ) do
    external_link = get_external_link()
    broker = Repo.get(Broker, broker_id)
    cred = Repo.get_by(Credential, broker_id: broker.id, active: true)
    city_id = if not is_nil(broker), do: broker.operating_city, else: 1
    city_id = if not is_nil(city_id), do: city_id, else: 1
    employment_type = if is_binary(employment_type), do: String.to_integer(employment_type), else: employment_type

    agent_to_assign =
      if broker.role_type_id == Broker.dsa()["id"] do
        AssignedBrokers.get_brokers_assigned_employee_id_for_hl(broker_id)
      else
        get_rr_agent_to_assign(city_id)
      end

    loan_amount = if is_binary(loan_amount), do: String.to_integer(loan_amount), else: loan_amount

    ch =
      Lead.changeset(%Lead{}, %{
        phone_number: phone_number,
        country_id: country_id,
        name: name,
        broker_id: broker_id,
        remarks: remarks,
        loan_amount: loan_amount,
        external_link: external_link,
        employee_credentials_id: agent_to_assign,
        city_id: city_id,
        employment_type: employment_type,
        lead_creation_date: lead_creation_date,
        bank_name: bank_name,
        branch_name: branch_name,
        loan_type: loan_type,
        property_stage: property_stage,
        property_type: property_type,
        processing_type: processing_type,
        old_broker_id: broker_id,
        old_organization_id: cred.organization_id,
        pan: pan,
        loan_subtype: loan_subtype
      })

    case Repo.insert(ch) do
      {:ok, lead} ->
        # creating sendbird channel
        CreateHLSendbirdChannel.perform(lead.id)

        # backup worker for creating channel between broker and employee
        Exq.enqueue(Exq, "sendbird", BnApis.CreateHLSendbirdChannel, [
          lead.id
        ])

        if(broker.role_type_id == Broker.dsa()["id"]) do
          LeadStatus.create_lead_status!(lead, 9, nil, nil, nil, nil)
        else
          LeadStatus.create_lead_status!(lead, 1, nil, nil, nil, nil)
        end

        {:ok, lead}

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  def get_rr_agent_to_assign(city_id) do
    latest_lead = Lead |> where([l], l.city_id == ^city_id) |> order_by(desc: :inserted_at) |> limit(1) |> Repo.one()

    latest_lead = if is_nil(latest_lead), do: Lead |> last |> Repo.one(), else: latest_lead

    base_hl_agent_query =
      EmployeeCredential
      |> where(
        [ec],
        ec.active == ^true and ec.employee_role_id == ^EmployeeRole.hl_agent().id and ec.hl_lead_allowed == ^true
      )

    next_employee =
      if not is_nil(latest_lead.employee_credentials_id) do
        all_employees = base_hl_agent_query |> where([ec], ec.city_id == ^city_id) |> order_by(asc: :inserted_at) |> Repo.all()

        current_agent_index = all_employees |> Enum.find_index(fn ec -> ec.id == latest_lead.employee_credentials_id end)

        employee_length = all_employees |> length()

        if is_nil(current_agent_index) || current_agent_index == employee_length - 1 do
          all_employees |> Enum.at(0)
        else
          all_employees |> Enum.at(current_agent_index + 1)
        end
      else
        base_hl_agent_query
        |> where([ec], ec.city_id == ^city_id)
        |> order_by(asc: :inserted_at)
        |> limit(1)
        |> Repo.one()
      end

    next_employee =
      if is_nil(next_employee) do
        base_hl_agent_query |> order_by(asc: :inserted_at) |> limit(1) |> Repo.one()
      else
        next_employee
      end

    if is_nil(next_employee) do
      nil
    else
      next_employee.id
    end
  end

  def get_agent_to_assign() do
    available_employees =
      EmployeeCredential
      |> where(
        [ec],
        ec.active == ^true and ec.employee_role_id == ^EmployeeRole.hl_agent().id and ec.hl_lead_allowed == ^true
      )
      |> Repo.all()
      |> Enum.map(& &1.id)

    today =
      Timex.now()
      |> Timex.Timezone.convert("Asia/Kolkata")
      |> Timex.beginning_of_day()

    # starting_day = Timex.shift(today, days: -1) |> DateTime.to_naive
    starting_day = today |> DateTime.to_naive()

    employee_id_map =
      Lead
      |> where([l], l.inserted_at >= ^starting_day and l.employee_credentials_id in ^available_employees)
      |> group_by([l], l.employee_credentials_id)
      |> select([l], {l.employee_credentials_id, count(l.id)})
      |> Repo.all()

    employee_id_map =
      available_employees
      |> Enum.map(fn ae ->
        this_em_count = employee_id_map |> Enum.find(fn eim -> elem(eim, 0) == ae end)

        if not is_nil(this_em_count) and not is_nil(elem(this_em_count, 1)) do
          {ae, elem(this_em_count, 1)}
        else
          {ae, 0}
        end
      end)

    employee_id_map = employee_id_map |> Enum.sort_by(fn sc -> elem(sc, 1) end) |> List.first()

    available_agent_id =
      if is_nil(employee_id_map) do
        first_employee = available_employees |> List.first()

        if not is_nil(first_employee) do
          available_employees |> Enum.random()
        else
          nil
        end
      else
        elem(employee_id_map, 0)
      end

    available_agent_id
  end

  def push_to_leadsquared(lead) do
    Exq.enqueue(
      Exq,
      "leadsquared_lead_push",
      BnApis.LeadsquaredLeadPushWorker,
      [lead.id]
    )
  end

  def update_docs!(%Lead{} = lead, docs) do
    ch =
      Lead.docs_changeset(lead, %{
        docs: docs
      })

    Repo.update!(ch)
  end

  def update_latest_lead_status!(%Lead{} = lead, latest_lead_status_id) do
    ch =
      Lead.latest_lead_status_changeset(lead, %{
        latest_lead_status_id: latest_lead_status_id
      })

    mark_is_last_status_seen(lead.id, false)
    Repo.update!(ch)
  end

  def mark_is_last_status_seen(lead_id, mark_as) do
    lead = get_homeloan_lead(lead_id)

    if not is_nil(lead) do
      lead |> Lead.changeset(%{"is_last_status_seen" => mark_as}) |> Repo.update()
    else
      {:error, "Lead not found"}
    end
  end

  def get_lead_from_external_link(external_link) do
    Repo.get_by(Lead, external_link: external_link)
  end

  def validate_lead_for_consent(lead) do
    lead = lead |> Repo.preload(:latest_lead_status)

    lead_status_identifier = LeadStatus.get_details(lead.latest_lead_status)["status_identifier"]

    if lead_status_identifier == "CLIENT_APPROVAL_PENDING" do
      true
    else
      false
    end
  end

  def transfer_lead(lead_id, new_employee_id, user_map) do
    lead = Repo.get(Lead, lead_id)
    old_employee_id = lead.employee_credentials_id
    changeset = Lead.changeset(lead, %{"employee_credentials_id" => new_employee_id})
    {:ok, ch} = AuditedRepo.update(changeset, user_map)

    Exq.enqueue(Exq, "sendbird", BnApis.UpdateHLSendbirdChannel, [
      lead_id,
      new_employee_id,
      old_employee_id
    ])

    ch
  end

  def get_external_link() do
    EntroyHelper.random()
  end

  def hl_notification_count(broker_id) do
    Lead
    |> where([l], l.is_last_status_seen == false and l.broker_id == ^broker_id)
    |> Repo.aggregate(:count, :id)
  end

  def get_homeloan_lead_by_phone(phone_number) do
    Repo.get_by(Lead, phone_number: phone_number)
  end

  def get_broker_using_lead_id(nil), do: nil

  def get_broker_using_lead_id(lead_id) do
    lead = get_homeloan_lead(lead_id)
    lead = Repo.preload(lead, [:broker, broker: [:credentials]])
    List.first(lead.broker.credentials)
  end

  def get_call_records_for_lead(lead_id) do
    Calls
    |> where([c], c.entity_type == ^homeloan_schema_name() and c.lead_id == ^lead_id)
    |> Repo.all()
    |> Enum.map(fn call ->
      lead_status = Repo.get_by(HLCallLeadStatus, call_details_id: call.id)
      lead_status = if lead_status, do: lead_status.lead_status_id, else: nil
      {call_from, call_to} = get_users_names_from_call_records(lead_id, call.call_type, call.call_with)

      %{
        "start_time" => call.start_time,
        "end_time" => call.end_time,
        "agent_number" => call.agent_number,
        "customer_number" => call.customer_number,
        "duration" => call.duration,
        "recording_url" => call.recording_url,
        "call_with" => call.call_with,
        "call_type" => call.call_type,
        "status_id" => lead_status,
        "inserted_at" => call.inserted_at |> Time.naive_to_epoch_in_sec(),
        "type" => "call_record_history",
        "call_from" => call_from,
        "call_to" => call_to
      }
    end)
  end

  def get_users_names_from_call_records(lead_id, call_type, call_with) do
    lead = Lead.get_homeloan_lead(lead_id) |> Repo.preload([:employee_credentials, :broker])

    case call_type do
      "inbound" ->
        call_to = lead.employee_credentials.name

        call_from =
          case call_with do
            "hl_lead" -> lead.name
            "broker" -> lead.broker.name
            _ -> nil
          end

        {call_from, call_to}

      "outbound" ->
        call_from = lead.employee_credentials.name

        call_to =
          case call_with do
            "hl_lead" -> lead.name
            "broker" -> lead.broker.name
            _ -> nil
          end

        {call_from, call_to}
    end
  end

  def get_document_upload_history(lead_id) do
    Document
    |> where([doc], doc.homeloan_lead_id == ^lead_id)
    |> Repo.all()
    |> Enum.map(fn d ->
      doc_type_details = DocType.get_details_by_id(d.doc_type)
      imgix_doc_url = S3Helper.get_imgix_url(d.doc_url)

      uploaded_by =
        case d.uploader_type do
          "Employee" -> (EmployeeCredential.fetch_employee_by_id(d.uploader_id) || %{}) |> Map.get(:name)
          "Broker" -> (Broker.get_broker_details_using_cred_id(d.uploader_id) || %{}) |> Map.get("broker_name")
          _ -> nil
        end

      %{
        "id" => d.id,
        "doc_url" => imgix_doc_url,
        "doc_name" => d.doc_name,
        "doc_type" => d.doc_type,
        "inserted_at" => d.inserted_at |> Time.naive_to_epoch_in_sec(),
        "access_to_cp" => d.access_to_cp,
        "mime_type" => d.mime_type,
        "uploader_type" => d.uploader_type,
        "status_id" => d.lead_status_id,
        "type" => "document_upload_history",
        "doc_type_name" => if(is_nil(doc_type_details), do: nil, else: doc_type_details.name),
        "uploaded_by" => uploaded_by
      }
    end)
  end

  def get_status_change_history(lead_id) do
    lead =
      Repo.get_by(Lead, id: lead_id)
      |> Repo.preload(homeloan_lead_statuses: from(ls in LeadStatus, order_by: [desc: ls.inserted_at]))

    lead.homeloan_lead_statuses
    |> Enum.map(fn lead_status ->
      LeadStatus.get_details(lead_status)
    end)
  end

  def get_loan_files_docs(lead_id, "V1") do
    lead = Lead.get_homeloan_lead(lead_id) |> Repo.preload(:homeloan_lead_statuses)
    sanctioned_status = lead.homeloan_lead_statuses |> Enum.find(fn s -> s.status_id == 15 end)
    disbursement_letters = LoanDisbursement.get_disbursement_letters(lead.id)

    if(not is_nil(sanctioned_status)) do
      sanctioned_letter = [
        %{
          "doc_url" => S3Helper.get_imgix_url(lead.sanctioned_doc_url),
          "inserted_at" => sanctioned_status.inserted_at |> Time.naive_to_epoch_in_sec(),
          "doc_name" => "Sanction Letter",
          "doc_id" => 0,
          "allow_delete" => false
        }
      ]

      disbursement_letters ++ sanctioned_letter
    else
      disbursement_letters
    end
  end

  def get_loan_files_docs(lead_id, "V2") do
    disbursement_letters = LoanDisbursement.get_disbursement_letters(lead_id)
    sanctioned_letters = LoanFiles.get_sanctioned_letter_from_loan_files(lead_id)

    otc_pdd_proof_docs = LoanDisbursement.get_otc_pdd_proof_docs(lead_id)
    disbursement_letters ++ sanctioned_letters ++ otc_pdd_proof_docs
  end

  def get_documents_based_on_lead_type(lead, version, is_employee_view) do
    cond do
      lead.processing_type == self_processing_type() ->
        get_loan_files_docs(lead.id, version)

      lead.processing_type == bn_processing_type() ->
        Document.fetch_lead_docs(lead, _for_admin = false, is_employee_view) ++ get_loan_files_docs(lead.id, version)

      true ->
        Document.fetch_lead_docs(lead, _for_admin = false, is_employee_view)
    end
  end
end
