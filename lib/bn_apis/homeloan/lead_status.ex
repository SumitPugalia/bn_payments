defmodule BnApis.Homeloan.LeadStatus do
  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query

  alias BnApis.Repo
  alias BnApis.Homeloan.LeadStatus
  alias BnApis.Homeloan.Status
  alias BnApis.Homeloan.Lead
  alias BnApis.Accounts.EmployeeCredential
  alias BnApis.Homeloan.LeadStatusNote
  alias BnApis.Homeloan.Bank
  alias BnApis.Helpers.Time
  alias BnApis.Homeloan.LoanFiles
  alias BnApis.Helpers.S3Helper
  alias BnApis.Homeloan.LoanDisbursement

  schema "homeloan_lead_statuses" do
    field(:status_id, :integer)
    field(:bank_ids, {:array, :integer})
    field(:amount, :integer)
    belongs_to(:homeloan_lead, Lead)
    belongs_to(:employee_credential, EmployeeCredential)
    belongs_to(:loan_file, LoanFiles)

    has_many(:homeloan_lead_status_notes, LeadStatusNote, foreign_key: :homeloan_lead_status_id)

    timestamps()
  end

  @required [:status_id, :homeloan_lead_id]
  @optional [:employee_credential_id, :bank_ids, :amount, :loan_file_id]

  @doc false
  def changeset(lead_status, attrs) do
    lead_status
    |> cast(attrs, @required ++ @optional)
    |> validate_required(@required)
    |> foreign_key_constraint(:homeloan_lead_id)
    |> foreign_key_constraint(:employee_credential_id)
  end

  def get_lead_status(id) do
    Repo.get_by(LeadStatus, id: id)
  end

  def create_lead_status!(
        homeloan_lead,
        status_id,
        bank_ids,
        amount,
        employee_credential_id,
        loan_file_id
      ) do
    changeset =
      LeadStatus.changeset(%LeadStatus{}, %{
        homeloan_lead_id: homeloan_lead.id,
        status_id: status_id,
        bank_ids: bank_ids,
        amount: amount,
        employee_credential_id: employee_credential_id,
        loan_file_id: loan_file_id
      })

    lead_status = Repo.insert!(changeset)
    Lead.update_latest_lead_status!(homeloan_lead, lead_status.id)
    lead_status
  end

  def get_loan_file_details(
        loan_file_status,
        _fetch_notes \\ false,
        append_employee_logs \\ false
      ) do
    status = Status.status_list()[loan_file_status.status_id]
    status_identifier = status["identifier"]

    description =
      case status_identifier do
        "PROCESSING_DOC_IN_BANKS" ->
          loan_file_status = Repo.preload(loan_file_status, :loan_file)
          bank_name = Bank.get_bank_name_from_id(loan_file_status.loan_file.bank_id)
          status["text"] |> String.replace("<banks>", bank_name)

        "OFFER_RECEIVED_FROM_BANKS" ->
          loan_file_status = Repo.preload(loan_file_status, :loan_file)
          bank_name = Bank.get_bank_name_from_id(loan_file_status.loan_file.bank_id)
          status["text"] |> String.replace("<banks>", bank_name)

        "HOME_LOAN_DISBURSED" ->
          disbursed_and_commission = LoanDisbursement.get_total_disbursed_and_commission_amount_for_loan_id(loan_file_status.loan_file_id)
          status["text"] |> String.replace("<amount>", get_amount_in_text(disbursed_and_commission.disbursed_amount))

        "COMMISSION_RECEIVED" ->
          disbursed_and_commission = LoanDisbursement.get_total_disbursed_and_commission_amount_for_loan_id(loan_file_status.loan_file_id)

          if(is_nil(disbursed_and_commission.commission_amount)) do
            status["text"] |> String.replace("₹<amount>", "")
          else
            status["text"] |> String.replace("<amount>", get_amount_in_text(disbursed_and_commission.commission_amount))
          end

        _ ->
          status["text"]
      end

    employee_name =
      case loan_file_status.employee_credential_id do
        nil ->
          "Broker"

        id ->
          EmployeeCredential.fetch_employee_by_id(id).name
      end

    description =
      if append_employee_logs do
        description <> " (Updated By #{employee_name})"
      else
        description
      end

    %{
      "status_identifier" => status_identifier,
      "description" => description,
      "updated_at" => Time.naive_second_to_millisecond(loan_file_status.inserted_at),
      "updated_at_unix" => loan_file_status.inserted_at |> Time.naive_to_epoch_in_sec(),
      "updated_by" => employee_name,
      "status_id" => Status.get_status_id_from_identifier(status_identifier),
      "type" => "status_timeline",
      "status_logo_url" => Status.get_status_logo_from_identifier(status_identifier)
    }
    |> append_loan_file_details(loan_file_status, "V2")
  end

  def get_details(
        homeloan_lead_status,
        fetch_notes \\ false,
        append_employee_logs \\ false,
        add_loan_file_bank_and_amount \\ false
      ) do
    status = Status.status_list()[homeloan_lead_status.status_id]
    status_identifier = status["identifier"]

    employee_name =
      if(not is_nil(homeloan_lead_status.employee_credential_id)) do
        EmployeeCredential.fetch_employee_by_id(homeloan_lead_status.employee_credential_id).name
      else
        "Backend"
      end

    description = get_status_description_for_lead(homeloan_lead_status, status["text"], status_identifier, employee_name, append_employee_logs, add_loan_file_bank_and_amount)

    details = %{
      "status_identifier" => status_identifier,
      "description" => description,
      "updated_at" => Time.naive_second_to_millisecond(homeloan_lead_status.inserted_at),
      "updated_at_unix" => homeloan_lead_status.inserted_at |> Time.naive_to_epoch_in_sec(),
      "updated_by" => employee_name,
      "type" => "lead_status_timeline",
      "status_logo_url" => Status.get_status_logo_from_identifier(status_identifier),
      "status_id" => Status.get_status_id_from_identifier(status_identifier)
    }

    if fetch_notes do
      Map.put(details, "notes", get_notes(homeloan_lead_status, description))
    else
      details
    end
  end

  def get_status_description_for_lead(homeloan_lead_status, status_text, status_identifier, employee_name, append_employee_logs, add_loan_file_bank_and_amount) do
    amount_text = get_amount_in_text(homeloan_lead_status.amount)
    bank_text = get_bank_text(homeloan_lead_status.bank_ids)

    description =
      if(add_loan_file_bank_and_amount) do
        bank_names =
          LoanFiles.get_all_loan_files(homeloan_lead_status.homeloan_lead_id)
          |> Enum.map(& &1.bank_name)
          |> Enum.join(",")

        case status_identifier do
          "PROCESSING_DOC_IN_BANKS" ->
            status_text |> String.replace("<banks>", bank_names)

          "OFFER_RECEIVED_FROM_BANKS" ->
            status_text |> String.replace("<banks>", bank_names)

          "HOME_LOAN_DISBURSED" ->
            disbursed_and_commission = LoanDisbursement.get_total_disbursed_and_commission_amount_for_lead_id(homeloan_lead_status.homeloan_lead_id)
            status_text |> String.replace("<amount>", get_amount_in_text(disbursed_and_commission.disbursed_amount))

          "COMMISSION_RECEIVED" ->
            disbursed_and_commission = LoanDisbursement.get_total_disbursed_and_commission_amount_for_lead_id(homeloan_lead_status.homeloan_lead_id)

            if(is_nil(disbursed_and_commission.commission_amount)) do
              status_text |> String.replace("₹<amount>", "")
            else
              status_text |> String.replace("<amount>", get_amount_in_text(disbursed_and_commission.commission_amount))
            end

          _ ->
            status_text
        end
      else
        status_text =
          if(not is_nil(homeloan_lead_status.amount) and homeloan_lead_status.amount > 0) do
            status_text |> String.replace("<amount>", amount_text)
          else
            status_text |> String.replace("₹<amount>", "")
          end

        status_text |> String.replace("<banks>", bank_text)
      end

    if append_employee_logs do
      description <> " (Updated By #{employee_name})"
    else
      description
    end
  end

  def append_loan_file_details(details, _loan_file_status, "V1"), do: details

  def append_loan_file_details(details, loan_file_status, _version) do
    loan_file_status = Repo.preload(loan_file_status, :loan_file)
    # 9 is client approval recieved, which doesnt have loan file details
    if loan_file_status.status_id != 9 do
      bank_logo_url = Bank.get_bank_logo_url_from_id(loan_file_status.loan_file.bank_id)

      Map.merge(details, %{
        "loan_file_id" => loan_file_status.loan_file.id,
        "application_id" => loan_file_status.loan_file.application_id,
        "bank_name" => Bank.get_bank_name_from_id(loan_file_status.loan_file.bank_id),
        "bank_logo_url" => if(is_nil(bank_logo_url), do: S3Helper.get_imgix_url("assets/default_bank_logo.png"), else: S3Helper.get_imgix_url(bank_logo_url)),
        "branch_name" => loan_file_status.loan_file.branch_location
      })
    else
      details
    end
  end

  defp get_notes(homeloan_lead_status, description) do
    homeloan_lead_status =
      homeloan_lead_status
      |> Repo.preload(homeloan_lead_status_notes: {from(lsn in LeadStatusNote, order_by: [desc: lsn.inserted_at]), [:homeloan_lead_status]})

    homeloan_lead_status.homeloan_lead_status_notes
    |> Enum.map(fn note ->
      LeadStatusNote.get_details(note, description)
    end)
  end

  def get_amount_in_text(nil) do
    ""
  end

  def get_amount_in_text(amount) when is_float(amount) do
    get_amount_in_text(trunc(amount))
  end

  def get_amount_in_text(amount) do
    amount_length = Integer.to_string(amount) |> String.length()

    case amount_length do
      x when x <= 3 ->
        "#{amount}"

      x when x > 3 and x <= 5 ->
        # amount_str =
        #   (amount / 1000)
        #   |> Float.round(2)
        #   |> Float.to_string()
        #   |> String.trim_trailing(".0")

        # "#{amount_str} Thousand"
        "#{amount}"

      x when x > 5 and x <= 7 ->
        amount_str =
          (amount / 100_000)
          |> Float.round(2)
          |> Float.to_string()
          |> String.trim_trailing(".0")

        "#{amount_str} Lacs"

      x when x > 7 ->
        amount_str =
          (amount / 10_000_000)
          |> Float.round(2)
          |> Float.to_string()
          |> String.trim_trailing(".0")

        "#{amount_str} CR"
    end
  end

  defp get_bank_text(nil) do
    ""
  end

  defp get_bank_text([]) do
    ""
  end

  defp get_bank_text(bank_ids) do
    Bank.get_bank_data(bank_ids) |> Enum.map(& &1.name) |> Enum.join(", ")
  end
end
