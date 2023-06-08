defmodule BnApis.Homeloan.LoanDisbursement do
  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query

  alias BnApis.Repo
  alias BnApis.Homeloan.LoanDisbursement
  alias BnApis.Stories.Schema.Invoice
  alias BnApis.Helpers.Utils
  alias BnApis.Homeloan.Lead
  alias BnApis.Helpers.Time
  alias BnApis.Homeloans
  alias BnApis.Helpers.S3Helper
  alias BnApis.Homeloan.LoanFiles
  alias BnApis.Homeloan.Bank
  alias BnApis.Helpers.ApplicationHelper
  alias BnApis.Stories.Invoice, as: Invoices
  alias BnApis.Helpers.AuditedRepo

  schema "loan_disbursements" do
    field :disbursement_date, :integer
    field :loan_disbursed, :integer
    field :loan_commission, :float
    field :otc_cleared, :boolean, default: false
    field :pdd_cleared, :boolean, default: false
    field :lan, :string
    field :disbursement_type, :string
    field :document_url, :string
    field :otc_pdd_proof_doc, :string
    field :invoice_pdf_url, :string

    # disbursed with rtgs or cheque
    field :disbursed_with
    field :active, :boolean, default: true
    field :commission_applicable_amount, :integer
    field(:commission_applicable_on, :string)
    field :commission_percentage, :float

    belongs_to :invoice, Invoice
    belongs_to :homeloan_lead, Lead
    belongs_to :loan_file, LoanFiles

    timestamps()
  end

  @required [:disbursement_date, :loan_disbursed, :homeloan_lead_id, :active]
  @optional [
    :lan,
    :disbursement_type,
    :document_url,
    :otc_cleared,
    :pdd_cleared,
    :invoice_id,
    :otc_pdd_proof_doc,
    :loan_file_id,
    :disbursed_with,
    :loan_commission,
    :invoice_pdf_url,
    :commission_applicable_on,
    :commission_applicable_amount,
    :commission_percentage
  ]

  @partial_disbursement %{
    "id" => 1,
    "name" => "partial",
    "identifier" => "partial"
  }

  @full_disbursement %{
    "id" => 2,
    "name" => "full",
    "identifier" => "full"
  }

  @commission_applicable_on [
    %{"id" => 1, "name" => "Sanctioned Amount", "identifier" => "sanctioned_amount"},
    %{"id" => 2, "name" => "Disbursement Amount", "identifier" => "disbursement_amount"},
    %{"id" => 3, "name" => "Other Amount", "identifier" => "commission_applicable_amount"}
  ]

  def update_invoice_id(loan_id, invoice_id) do
    __MODULE__
    |> update(set: [invoice_id: ^invoice_id])
    |> where(id: ^loan_id)
    |> Repo.update_all([])
  end

  def get_employee_id_related_to_lead(id) do
    LoanDisbursement
    |> join(:left, [l], ld in assoc(l, :homeloan_lead))
    |> where([l], l.id == ^id)
    |> select([l, ld], ld.employee_credentials_id)
    |> Repo.one()
  end

  def partial_disbursement, do: @partial_disbursement
  def full_disbursement, do: @full_disbursement

  @doc false
  def changeset(lead, attrs) do
    lead
    |> cast(attrs, @required ++ @optional)
    |> validate_required(@required)
    |> foreign_key_constraint(:homeloan_lead_id)
    |> validate_disbursement_amount()
    |> validate_commission_applicable_on()
  end

  def validate_commission_applicable_on(changeset) do
    commission_applicable_on = get_field(changeset, :commission_applicable_on)

    valid_commission_applicable_list = @commission_applicable_on |> Enum.map(& &1["identifier"])

    if(is_nil(commission_applicable_on) or Enum.member?(valid_commission_applicable_list, commission_applicable_on)) do
      changeset
    else
      add_error(changeset, :commission_applicable_on, "is invalid")
    end
  end

  def commission_applicable_list, do: @commission_applicable_on

  defp validate_disbursement_amount(changeset) do
    case changeset.valid? do
      true ->
        loan_file_id = get_field(changeset, :loan_file_id)
        sanctioned_amount = LoanFiles.get_loan_file(loan_file_id).sanctioned_amount

        current_disbursement_amount = get_field(changeset, :loan_disbursed)
        disbursement_id = get_field(changeset, :id)

        disbursements = LoanDisbursement.get_loan_disbursements_for_file_id(loan_file_id)

        total_disbursed_amount =
          disbursements
          |> Enum.reduce(0, fn dis, acc ->
            # if the changeset is not getting called from edit disbursement api
            if is_nil(disbursement_id) do
              acc + (dis.loan_disbursed || 0)
            else
              # disbursement amount not to be considered for the same id for which we are editing disbursement
              if disbursement_id != dis.disbursement_id, do: acc + (dis.loan_disbursed || 0), else: acc + 0
            end
          end)

        if total_disbursed_amount + current_disbursement_amount > sanctioned_amount do
          add_error(changeset, :loan_disbursed, "Disbursed amount exceeds the sanctioned amount")
        else
          changeset
        end

      _ ->
        changeset
    end
  end

  def add_homeloan_disbursement(
        params = %{
          "lead_id" => homeloan_lead_id,
          "disbursement_date" => disbursement_date,
          "loan_disbursed" => loan_disbursed
        }
      ) do
    loan_file = LoanFiles |> Repo.get_by(id: params["loan_file_id"]) |> Repo.preload(:bank)

    commission_applicable_on =
      case loan_file do
        nil -> nil
        loan_file -> Atom.to_string(loan_file.bank.commission_on)
      end

    LoanDisbursement.changeset(%LoanDisbursement{}, %{
      disbursement_date: disbursement_date,
      homeloan_lead_id: homeloan_lead_id,
      loan_disbursed: loan_disbursed,
      loan_commission: params["loan_commission"],
      otc_cleared: params["otc_cleared"],
      pdd_cleared: params["pdd_cleared"],
      lan: params["lan"],
      disbursement_type: params["disbursement_type"],
      document_url: params["document_url"],
      otc_pdd_proof_doc: params["otc_pdd_proof_doc"],
      disbursed_with: params["disbursed_with"],
      loan_file_id: params["loan_file_id"],
      invoice_pdf_url: params["invoice_pdf_url"],
      invoice_id: params["invoice_id"],
      commission_applicable_on: commission_applicable_on
    })
    |> Repo.insert()
  end

  def get_already_disbursed_for_sanctioned_banks(nil), do: nil

  def get_already_disbursed_for_sanctioned_banks(loan_file_id) do
    loan_file =
      LoanFiles
      |> join(:inner, [l], b in Bank, on: b.id == l.bank_id)
      |> where([l, b], l.id == ^loan_file_id and b.commission_on == :sanctioned_amount)
      |> Repo.one()

    case loan_file do
      nil ->
        nil

      _ ->
        LoanDisbursement
        |> join(:inner, [l], i in Invoice, on: l.invoice_id == i.id and i.status == "paid")
        |> where([l, i], not is_nil(l.loan_commission) and l.loan_file_id == ^loan_file_id)
        |> select([l, i], %{invoice_id: i.id})
        |> Repo.all()
        |> List.first()
    end
  end

  def add_hl_disbursement_from_panel(
        params = %{
          "lead_id" => homeloan_lead_id,
          "disbursement_date" => _disbursement_date,
          "loan_disbursed" => _loan_disbursed
        }
      ) do
    case add_homeloan_disbursement(params) do
      {:ok, _changeset} ->
        homeloan_lead = Lead.get_homeloan_lead(homeloan_lead_id)
        Homeloans.update_lead(homeloan_lead, %{"fully_disbursed" => params["fully_disbursed"]})
        {:ok, nil}

      {:error, error} ->
        {:error, error}
    end
  end

  def add_hl_disbursement_from_app(params) do
    invoice_id =
      case get_already_disbursed_for_sanctioned_banks(params["loan_file_id"]) do
        nil -> nil
        disbursement -> disbursement.invoice_id
      end

    params = params |> Map.put("invoice_id", invoice_id)
    add_homeloan_disbursement(params)
  end

  def get_loan_disbursements(lead_id, is_employee, order_by \\ "desc") do
    lead_id = if is_binary(lead_id), do: String.to_integer(lead_id), else: lead_id

    query =
      LoanDisbursement
      |> join(:inner, [ld], l in Lead, on: l.id == ld.homeloan_lead_id and l.active == true)
      |> where([ld, l], ld.homeloan_lead_id == ^lead_id and ld.active == ^true)

    query =
      if(order_by == "desc") do
        query |> order_by([ld, l], desc: ld.disbursement_date)
      else
        query |> order_by([ld, l], asc: ld.disbursement_date)
      end

    query
    |> Repo.all()
    |> Repo.preload([:invoice, :loan_file, homeloan_lead: [:broker], loan_file: [:bank]])
    |> Enum.map(fn loan ->
      {application_id, bank_name, bank_logo_url, branch_location} =
        if is_nil(loan.loan_file_id) do
          {nil, nil, nil, nil}
        else
          loan_file = Repo.get_by(LoanFiles, id: loan.loan_file_id)
          {loan_file.application_id, Bank.get_bank_name_from_id(loan_file.bank_id), Bank.get_bank_logo_url_from_id(loan_file.bank_id), loan_file.branch_location}
        end

      is_editable = is_disbursement_editable(loan, is_employee)

      %{
        disbursement_id: loan.id,
        application_id: application_id,
        bank_name: bank_name,
        bank_logo_url: if(is_nil(bank_logo_url), do: S3Helper.get_imgix_url("assets/default_bank_logo.png"), else: S3Helper.get_imgix_url(bank_logo_url)),
        branch_location: branch_location,
        lan: loan.lan,
        disbursement_date: loan.disbursement_date,
        loan_disbursed: loan.loan_disbursed,
        loan_commission: get_loan_commission(loan),
        display_loan_disbursed: Utils.format_money_new(loan.loan_disbursed),
        display_loan_commission: Utils.format_money_new(loan.loan_commission),
        invoice_id: loan.invoice_id,
        disbursement_type: loan.disbursement_type,
        document_url: S3Helper.get_imgix_url(loan.document_url),
        otc_cleared: loan.otc_cleared,
        pdd_cleared: loan.pdd_cleared,
        disbursed_with: loan.disbursed_with,
        s3_prefix_url: ApplicationHelper.get_imgix_domain(),
        otc_pdd_proof_doc: S3Helper.get_imgix_url(loan.otc_pdd_proof_doc),
        otc_pdd_proof_key: loan.otc_pdd_proof_doc,
        invoice_pdf_url: get_invoice_pdf_url(loan),
        invoice_number: if(not is_nil(loan.invoice), do: loan.invoice.invoice_number, else: nil),
        invoice_date: if(not is_nil(loan.invoice), do: loan.invoice.invoice_date, else: nil),
        loan_commission_paid: is_loan_commission_paid(loan),
        invoice_status: get_invoice_status(loan),
        invoice_status_display_name: get_invoice_status_display_name(loan),
        inserted_at: loan.inserted_at,
        loan_file_id: loan.loan_file_id,
        is_editable: is_editable,
        loan_insurance_amount: loan.loan_file.loan_insurance_amount,
        loan_insurance_done: loan.loan_file.loan_insurance_done,
        display_loan_insurance_amount: Utils.format_money_new(loan.loan_file.loan_insurance_amount),
        commission_applicable_amount: loan.commission_applicable_amount,
        commission_applicable_on: loan.commission_applicable_on
      }
    end)
  end

  defp get_invoice_status_display_name(loan) do
    cond do
      not is_nil(loan.invoice_pdf_url) -> "Paid"
      not is_nil(loan.invoice) -> Invoices.get_invoice_display_status_text(loan.invoice.status, nil, nil, Invoice.type_dsa())
      true -> nil
    end
  end

  defp get_invoice_status(loan) do
    cond do
      not is_nil(loan.invoice_pdf_url) -> "paid"
      not is_nil(loan.invoice) -> loan.invoice.status
      true -> nil
    end
  end

  defp is_loan_commission_paid(loan) do
    cond do
      not is_nil(loan.invoice_pdf_url) -> true
      not is_nil(loan.invoice) and loan.invoice.status == "paid" -> true
      true -> false
    end
  end

  defp get_loan_commission(loan) do
    cond do
      loan.homeloan_lead.broker.role_type_id == 1 and is_nil(loan.invoice_pdf_url) -> nil
      loan.homeloan_lead.broker.role_type_id == 1 -> loan.loan_disbursed * 0.75
      true -> Utils.format_float(loan.loan_commission)
    end
  end

  defp get_invoice_pdf_url(loan) do
    case loan.homeloan_lead.broker.role_type_id do
      1 -> if is_nil(loan.invoice_pdf_url), do: nil, else: S3Helper.get_imgix_url(loan.invoice_pdf_url)
      _ -> if not is_nil(loan.invoice), do: loan.invoice.invoice_pdf_url, else: nil
    end
  end

  def is_invoice_already_raised(loan_file_id) do
    count =
      LoanDisbursement
      |> where([ld], ld.loan_file_id == ^loan_file_id and ld.active == true and not is_nil(ld.invoice_id))
      |> Repo.aggregate(:count, :id)

    count > 0
  end

  def is_disbursement_editable(_loan_disbursement, true), do: false

  def is_disbursement_editable(loan_disbursement, _) do
    case loan_disbursement.homeloan_lead.processing_type do
      "bn" -> false
      _ -> is_nil(loan_disbursement.invoice_id) and is_disbursement_latest(loan_disbursement)
    end
  end

  def is_disbursement_latest(ld) do
    loan_file_id = ld.loan_file_id

    recent_disbursement =
      LoanDisbursement
      |> where([ld], ld.loan_file_id == ^loan_file_id and ld.active == ^true)
      |> order_by([ld], desc: ld.inserted_at)
      |> Repo.all()
      |> List.first()

    recent_disbursement.id == ld.id
  end

  def get_loan_disbursements_for_file_id(loan_file_id) do
    loan_file_id = if is_binary(loan_file_id), do: String.to_integer(loan_file_id), else: loan_file_id

    LoanDisbursement
    |> where([ld], ld.loan_file_id == ^loan_file_id and ld.active == ^true)
    |> order_by([ld], desc: ld.inserted_at)
    |> Repo.all()
    |> Repo.preload([:invoice])
    |> Enum.map(fn loan ->
      %{
        disbursement_id: loan.id,
        lan: loan.lan,
        disbursement_date: loan.disbursement_date,
        loan_disbursed: loan.loan_disbursed,
        loan_commission: Utils.format_float(loan.loan_commission),
        display_loan_disbursed: Utils.format_money_new(loan.loan_disbursed),
        display_loan_commission: Utils.format_money_new(loan.loan_commission),
        invoice_id: loan.invoice_id,
        disbursement_type: loan.disbursement_type,
        document_url: S3Helper.get_imgix_url(loan.document_url),
        document_key: loan.document_url,
        otc_cleared: loan.otc_cleared,
        pdd_cleared: loan.pdd_cleared,
        disbursed_with: loan.disbursed_with,
        otc_pdd_proof_doc: S3Helper.get_imgix_url(loan.otc_pdd_proof_doc),
        invoice_pdf_url: if(not is_nil(loan.invoice), do: loan.invoice.invoice_pdf_url, else: nil),
        invoice_number: if(not is_nil(loan.invoice), do: loan.invoice.invoice_number, else: nil),
        invoice_date: if(not is_nil(loan.invoice), do: loan.invoice.invoice_date, else: nil),
        loan_commission_paid: if(not is_nil(loan.invoice) and loan.invoice.status == "paid", do: true, else: false),
        invoice_status: if(not is_nil(loan.invoice), do: loan.invoice.status, else: nil),
        inserted_at: loan.inserted_at,
        commission_applicable_amount: loan.commission_applicable_amount,
        commission_applicable_on: loan.commission_applicable_on
      }
    end)
  end

  def edit_homeloan_disbursement(params, user_map) do
    disbursement_id = if is_binary(params["id"]), do: String.to_integer(params["id"]), else: params["id"]
    disbursement = Repo.get_by(LoanDisbursement, id: disbursement_id) |> Repo.preload(loan_file: :bank)
    disbursement |> LoanDisbursement.changeset(params) |> AuditedRepo.update(user_map)
  end

  def delete_homeloan_disbursement(disbursement_id, user_map) do
    disbursement_id = if is_binary(disbursement_id), do: String.to_integer(disbursement_id), else: disbursement_id
    disbursement = Repo.get_by(LoanDisbursement, id: disbursement_id)
    disbursement |> LoanDisbursement.changeset(%{"active" => false}) |> AuditedRepo.update(user_map)
  end

  def get_disbursement_letters(lead_id, version \\ "V1") do
    LoanDisbursement
    |> where([ld], ld.homeloan_lead_id == ^lead_id and ld.active == ^true)
    |> order_by([ld], desc: ld.inserted_at)
    |> Repo.all()
    |> Enum.map(fn ld ->
      ld = Repo.preload(ld, :loan_file)
      bank_logo_url = Bank.get_bank_logo_url_from_id(ld.loan_file.bank_id)

      %{
        "doc_url" => S3Helper.get_imgix_url(ld.document_url),
        "inserted_at" => ld.inserted_at |> Time.naive_to_epoch_in_sec(),
        "doc_name" => "Disbursement Letter",
        "doc_type_name" => "Disbursement Letter",
        "doc_id" => ld.id,
        "allow_delete" => false,
        "bank_name" => Bank.get_bank_name_from_id(ld.loan_file.bank_id),
        "bank_logo_url" => if(is_nil(bank_logo_url), do: S3Helper.get_imgix_url("assets/default_bank_logo.png"), else: S3Helper.get_imgix_url(bank_logo_url)),
        "application_id" => ld.loan_file.application_id,
        "branch_location" => ld.loan_file.branch_location,
        "loan_file_id" => ld.loan_file_id
      }
      |> maybe_append_loan_file_details(ld, version)
    end)
  end

  def maybe_append_loan_file_details(details, _ld, "V1"), do: details

  def maybe_append_loan_file_details(details, ld, _version) do
    ld = Repo.preload(ld, :loan_file)
    bank_logo_url = Bank.get_bank_logo_url_from_id(ld.loan_file.bank_id)

    Map.put(details, "loan_file_details", %{
      "application_id" => ld.loan_file.application_id,
      "bank_name" => Bank.get_bank_name_from_id(ld.loan_file.bank_id),
      "bank_logo_url" => if(is_nil(bank_logo_url), do: S3Helper.get_imgix_url("assets/default_bank_logo.png"), else: S3Helper.get_imgix_url(bank_logo_url))
    })
  end

  def get_otc_pdd_proof_docs(lead_id) do
    LoanDisbursement
    |> where([ld], ld.homeloan_lead_id == ^lead_id and ld.active == ^true and not is_nil(ld.otc_pdd_proof_doc))
    |> order_by([ld], desc: ld.inserted_at)
    |> Repo.all()
    |> Enum.map(fn ld ->
      ld = Repo.preload(ld, :loan_file)
      bank_logo_url = Bank.get_bank_logo_url_from_id(ld.loan_file.bank_id)

      %{
        "doc_url" => S3Helper.get_imgix_url(ld.otc_pdd_proof_doc),
        "inserted_at" => ld.inserted_at |> Time.naive_to_epoch_in_sec(),
        "doc_name" => "Bank Confirmation Proof",
        "doc_type_name" => "Bank Confirmation Proof",
        "doc_id" => ld.id,
        "allow_delete" => false,
        "bank_name" => Bank.get_bank_name_from_id(ld.loan_file.bank_id),
        "bank_logo_url" => if(is_nil(bank_logo_url), do: S3Helper.get_imgix_url("assets/default_bank_logo.png"), else: S3Helper.get_imgix_url(bank_logo_url)),
        "application_id" => ld.loan_file.application_id,
        "branch_location" => ld.loan_file.branch_location,
        "loan_file_id" => ld.loan_file_id
      }
    end)
  end

  def get_latest_disbursement_amount_of_lead(homeloan_lead) do
    lateset_disbursement =
      LoanDisbursement
      |> where([ld], ld.homeloan_lead_id == ^homeloan_lead.id and ld.active == ^true)
      |> order_by([ld], desc: ld.inserted_at)
      |> Repo.all()
      |> List.first()

    lateset_disbursement.loan_disbursed
  end

  def get_latest_commission_amount_of_lead(homeloan_lead) do
    lateset_disbursement =
      LoanDisbursement
      |> where([ld], ld.homeloan_lead_id == ^homeloan_lead.id and ld.active == ^true)
      |> order_by([ld], desc: ld.inserted_at)
      |> Repo.all()
      |> List.first()

    lateset_disbursement.loan_commission
  end

  def get_total_disbursed_and_commission_amount_for_loan_id(loan_file_id) do
    LoanDisbursement
    |> where([l], l.loan_file_id == ^loan_file_id and l.active == true)
    |> select([l], %{
      disbursed_amount: sum(l.loan_disbursed),
      commission_amount: sum(l.loan_commission)
    })
    |> Repo.one()
  end

  def get_total_disbursed_and_commission_amount_for_lead_id(lead_id) do
    LoanDisbursement
    |> where([l], l.homeloan_lead_id == ^lead_id and l.active == true)
    |> select([l], %{
      disbursed_amount: sum(l.loan_disbursed),
      commission_amount: sum(l.loan_commission)
    })
    |> Repo.one()
  end

  def change_commission_on_from_panel(disbursement_id, new_amount, commission_applicable_on, user_map) do
    disbursement_id = if is_binary(disbursement_id), do: String.to_integer(disbursement_id), else: disbursement_id
    disbursement = Repo.get_by(LoanDisbursement, id: disbursement_id) |> Repo.preload([:homeloan_lead, :loan_file, :invoice])
    amount = if(new_amount in [nil, 0], do: get_existing_amount_using_commission_applicable_on(disbursement, commission_applicable_on), else: new_amount)
    loan_commission = if(not is_nil(disbursement.commission_percentage), do: Utils.format_float(amount * disbursement.commission_percentage / 100), else: nil)

    try do
      changed_amout =
        cond do
          new_amount in [nil, 0] -> {:ok, ""}
          not is_nil(disbursement.invoice) and disbursement.invoice.status in ["paid" , "approved_by_finance"] -> {:error, "Can not change amount after approved"}
          true -> update_loan_disburse_amt_and_sanctioned_amount(commission_applicable_on, disbursement, amount, user_map)
        end

      case changed_amout do
        {:ok, _} ->
          changed_disbursement =
            disbursement
            |> LoanDisbursement.changeset(%{"commission_applicable_on" => commission_applicable_on, "loan_commission" => loan_commission})
            |> AuditedRepo.update(user_map)

          case changed_disbursement do
            {:ok, _changed_disbursement} ->
              if(not is_nil(disbursement.invoice_id)) do
                invoice = Invoice |> Repo.get_by(id: disbursement.invoice_id)
                Invoices.generate_invoice_pdf(%{"uuid" => invoice.uuid, "loan_commission" => disbursement.commission_percentage}, user_map)
              else
                {:ok, "succesfully updated"}
              end

            {:error, error} ->
              {:error, error}
          end

        {:error, error} ->
          {:error, error}
      end
    rescue
      err ->
        {:error, err}
    end
  end

  def update_loan_disburse_amt_and_sanctioned_amount(commission_applicable_on, disbursement, amount, user_map) do
    case commission_applicable_on do
      "sanctioned_amount" ->
        updated_result = disbursement.loan_file |> LoanFiles.changeset(%{"sanctioned_amount" => amount}) |> AuditedRepo.update(user_map)

        case updated_result do
          {:ok, _updated_result} -> send_notification(disbursement.loan_file.sanctioned_amount, amount, disbursement.homeloan_lead, "Sanctioned")
          {:error, changeset} -> {:error, changeset}
        end

      "disbursement_amount" ->
        updated_result = disbursement |> LoanDisbursement.changeset(%{"loan_disbursed" => amount}) |> AuditedRepo.update(user_map)

        case updated_result do
          {:ok, _updated_result} ->
            send_notification(disbursement.loan_disbursed, amount, disbursement.homeloan_lead, "Disbursement")

          {:error, changeset} ->
            {:error, changeset}
        end

      "commission_applicable_amount" ->
        updated_result = disbursement |> LoanDisbursement.changeset(%{"commission_applicable_amount" => amount}) |> AuditedRepo.update(user_map)

        case updated_result do
          {:ok, _updated_result} -> send_notification(disbursement.commission_applicable_amount, amount, disbursement.homeloan_lead, "Commission Payout")
          {:error, changeset} -> {:error, changeset}
        end

      _ ->
        {:error, "invalid commssion applicable"}
    end
  end

  def get_existing_amount_using_commission_applicable_on(disbursement, commission_applicable_on) do
    case commission_applicable_on do
      "sanctioned_amount" -> disbursement.loan_file.sanctioned_amount
      "disbursement_amount" -> disbursement.loan_disbursed
      "commission_applicable_amount" -> disbursement.commission_applicable_amount
      _ -> nil
    end
  end

  def send_notification(old_amount, new_amount, lead, changed_amount_key) do
    old_amount = Utils.format_money_new(old_amount)
    new_amount = Utils.format_money_new(new_amount)

    message =
      if(old_amount == "-") do
        "#{changed_amount_key} amount for Lead #{lead.name} has been changed to #{new_amount}"
      else
        "#{changed_amount_key} amount for Lead #{lead.name} has been changed from #{old_amount} to #{new_amount}"
      end

    Exq.enqueue(Exq, "send_notification", BnApis.Homeloan.HomeloanNotificationHelper, [lead.id, message])
    {:ok, "success"}
  end

  def get_dsa_commission_amount(loan_disbursement, loan_commission_percent) do
    commission_applicable_on =
      if is_nil(loan_disbursement.commission_applicable_on) do
        Atom.to_string(loan_disbursement.loan_file.bank.commission_on)
      else
        loan_disbursement.commission_applicable_on
      end

    case commission_applicable_on do
      "sanctioned_amount" -> loan_disbursement.loan_file.sanctioned_amount * loan_commission_percent / 100
      "disbursement_amount" -> if is_nil(loan_disbursement.loan_disbursed), do: nil, else: loan_disbursement.loan_disbursed * loan_commission_percent / 100
      "commission_applicable_amount" -> loan_disbursement.commission_applicable_amount * loan_commission_percent / 100
      _ -> nil
    end
  end

  def get_amount_on_commission_is_given(loan_disbursement) do
    commission_applicable_on =
      if is_nil(loan_disbursement.commission_applicable_on) do
        Atom.to_string(loan_disbursement.loan_file.bank.commission_on)
      else
        loan_disbursement.commission_applicable_on
      end

    case commission_applicable_on do
      "sanctioned_amount" -> loan_disbursement.loan_file.sanctioned_amount
      "disbursement_amount" -> loan_disbursement.loan_disbursed
      "commission_applicable_amount" -> loan_disbursement.commission_applicable_amount
      _ -> nil
    end
  end
end
