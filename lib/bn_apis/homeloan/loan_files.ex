defmodule BnApis.Homeloan.LoanFiles do
  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query

  alias BnApis.Repo
  alias BnApis.Homeloan.Status
  alias BnApis.Homeloans
  alias BnApis.Homeloan.LoanFiles
  alias BnApis.Helpers.Time
  alias BnApis.Homeloan.Bank
  alias BnApis.Helpers.S3Helper
  alias BnApis.Homeloan.LoanDisbursement
  alias BnApis.Helpers.Utils
  alias BnApis.Homeloan.Lead
  alias BnApis.Helpers.ApplicationHelper
  alias BnApis.Homeloan.LoanFileStatus
  alias BnApisWeb.Helpers.PhoneHelper, as: Phone

  schema "loan_files" do
    field(:active, :boolean, default: true)
    field(:application_id, :string)
    field(:bank_rm_name, :string)
    field(:bank_rm_phone_number, :string)
    field(:sanctioned_amount, :integer)
    field(:sanctioned_doc_url, :string)
    field(:lan, :string)
    field(:rejected_lost_reason, :string)
    field(:rejected_doc_url, :string)
    field(:bank_offer_doc_url, :string)
    field(:branch_location, :string)
    field(:original_agreement_doc_url, :string)
    field(:loan_insurance_done, :boolean)
    field(:loan_insurance_amount, :integer)

    belongs_to(:bank, Bank)
    belongs_to(:homeloan_lead, Lead)

    belongs_to(:latest_file_status, LoanFileStatus,
      foreign_key: :latest_file_status_id,
      references: :id
    )

    has_many(:loan_file_statuses, LoanFileStatus, foreign_key: :loan_file_id)
    has_many(:loan_disbursements, LoanDisbursement, foreign_key: :loan_file_id)

    timestamps()
  end

  @required [:active, :application_id, :homeloan_lead_id, :bank_id, :branch_location]
  @optional [
    :lan,
    :bank_rm_name,
    :bank_rm_phone_number,
    :sanctioned_amount,
    :sanctioned_doc_url,
    :rejected_lost_reason,
    :rejected_doc_url,
    :bank_offer_doc_url,
    :original_agreement_doc_url,
    :loan_insurance_done,
    :loan_insurance_amount,
    :latest_file_status_id
  ]

  @doc false
  def changeset(loan_file, attrs) do
    loan_file
    |> cast(attrs, @required ++ @optional)
    |> validate_required(@required)
    |> foreign_key_constraint(:homeloan_lead_id)
    |> foreign_key_constraint(:bank_id)
    |> foreign_key_constraint(:latest_file_status_id)
    |> unique_constraint(:application_id)
    |> unique_constraint(:lan)
    |> validate_rm_phone_number()
  end

  def validate_rm_phone_number(changeset) do
    bank_rm_phone_number = get_field(changeset, :bank_rm_phone_number)

    case bank_rm_phone_number do
      nil ->
        changeset

      _ ->
        case Phone.parse_phone_number("+91", bank_rm_phone_number) do
          {:ok, _phone_number, _} ->
            changeset

          _ ->
            add_error(changeset, :phone_number, "Invalid bank RM phone_number")
        end
    end
  end

  def create_loan_file_from_panel(
        params = %{
          "lead_id" => homeloan_lead_id,
          "loan_files" => loan_files
        },
        session_data
      ) do
    homeloan_lead_id = if is_binary(homeloan_lead_id), do: String.to_integer(homeloan_lead_id), else: homeloan_lead_id

    Repo.transaction(fn ->
      has_lead_non_failed_files = has_lead_non_failed_files(homeloan_lead_id)

      Enum.map(loan_files, fn loan_file ->
        changeset(%LoanFiles{}, %{
          homeloan_lead_id: homeloan_lead_id,
          application_id: loan_file["application_id"],
          bank_id: loan_file["bank_id"],
          active: true,
          branch_location: loan_file["branch_location"]
        })
        |> Repo.insert()
        |> case do
          {:ok, loan_file} ->
            status_id = Status.get_status_id_from_identifier("PROCESSING_DOC_IN_BANKS")
            employee_id = session_data |> get_in(["profile", "employee_id"])
            LoanFileStatus.create_loan_file_status(loan_file, status_id, params["note"], employee_id)

            if not has_lead_non_failed_files do
              params = Map.put(params, "status_identifier", "PROCESSING_DOC_IN_BANKS")
              params = Map.put(params, "loan_file_id", loan_file.id)

              case Homeloans.update_status(params, session_data, "V2") do
                {:ok, nil} ->
                  loan_file

                {:error, msg} ->
                  Repo.rollback(msg)
              end
            end

          {:error, changeset} ->
            Repo.rollback(changeset)
        end
      end)
    end)
  end

  def update_loan_file_from_panel(
        params = %{
          "status_identifier" => status_identifier,
          "loan_file_id" => loan_file_id
        },
        session_data
      ) do
    loan_file = Repo.get_by(LoanFiles, id: loan_file_id)

    case loan_file do
      nil ->
        {:error, "Loan file does not exist"}

      loan_file ->
        Repo.transaction(fn ->
          case update_loan_file_details(params, loan_file) do
            {:ok, _changeset} ->
              status_id = Status.get_status_id_from_identifier(status_identifier)
              employee_id = session_data |> get_in(["profile", "employee_id"])

              same_status_exists =
                LoanFileStatus
                |> where([lfs], lfs.loan_file_id == ^loan_file_id and lfs.status_id == ^status_id)
                |> Repo.all()

              if length(same_status_exists) == 0, do: LoanFileStatus.create_loan_file_status(loan_file, status_id, params["note"], employee_id)

              if is_loan_file_ahead_of_all(loan_file.homeloan_lead_id, status_identifier) and check_failed_scenarios(status_identifier, params["lead_id"]) do
                case Homeloans.update_status(params, session_data, "V2") do
                  {:ok, nil} ->
                    {:ok, nil}

                  {:error, msg} ->
                    Repo.rollback(msg)
                end
              else
                {:ok, nil}
              end

            {:error, error} ->
              {:error, error}
          end
        end)
    end
  end

  def update_loan_file_from_panel(_, _), do: {:error, "Invalid Params"}

  defp update_loan_file_details(params, loan_file) do
    params = Map.put(params, "status_id", Status.get_status_id_from_identifier(params["status_identifier"]))
    loan_file |> LoanFiles.changeset(params) |> Repo.update()
  end

  def is_loan_file_ahead_of_all(lead_id, status_identifier) do
    incoming_status_id = Status.get_status_id_from_identifier(status_identifier)
    incoming_status_order = Status.status_list()[incoming_status_id]["order_for_employee_panel"]

    list_of_existing_status_order = get_list_of_status_ids_for_lead(lead_id) |> get_order_of_status_ids() |> Enum.sort()

    if(not is_nil(List.last(list_of_existing_status_order))) do
      incoming_status_order >= List.last(list_of_existing_status_order)
    else
      true
    end
  end

  def get_list_of_status_ids_for_lead(lead_id) do
    lead = Lead.get_homeloan_lead(lead_id) |> Repo.preload(:loan_files)

    Enum.reduce(lead.loan_files, [], fn loan_file, acc ->
      loan_file = loan_file |> Repo.preload(:latest_file_status)
      # failed status not to be considered
      if loan_file.latest_file_status.status_id != 8 do
        acc ++ [loan_file.latest_file_status.status_id]
      else
        acc
      end
    end)
  end

  def get_order_of_status_ids(status_ids_list) do
    Enum.map(status_ids_list, fn status_id ->
      Status.status_list()[status_id]["order_for_employee_panel"]
    end)
  end

  def create_loan_file(
        params = %{
          "lead_id" => homeloan_lead_id,
          "application_id" => application_id,
          "bank_id" => bank_id,
          "branch_location" => branch_location
        },
        session_data
      ) do
    Repo.transaction(fn ->
      has_lead_non_failed_files = has_lead_non_failed_files(homeloan_lead_id)

      changeset(%LoanFiles{}, %{
        homeloan_lead_id: homeloan_lead_id,
        application_id: application_id,
        bank_id: bank_id,
        active: true,
        status_id: Status.get_status_id_from_identifier("PROCESSING_DOC_IN_BANKS"),
        branch_location: branch_location
      })
      |> Repo.insert()
      |> case do
        {:ok, loan_file} ->
          status_id = Status.get_status_id_from_identifier("PROCESSING_DOC_IN_BANKS")
          LoanFileStatus.create_loan_file_status(loan_file, status_id, params["note"])
          broker_id = session_data |> get_in(["profile", "broker_id"])

          if not has_lead_non_failed_files do
            params = Map.put(params, "status_identifier", "PROCESSING_DOC_IN_BANKS")
            params = Map.put(params, "loan_file_id", loan_file.id)
            Homeloans.update_lead_status_for_dsa(params, broker_id, "V2")
          else
            {:ok, "Loan-File created"}
          end

        {:error, changeset} ->
          Repo.rollback(changeset)
      end
    end)
  end

  def create_loan_file(_, _), do: {:error, "Invalid Params"}

  def update_loan_file(
        params = %{
          "status_identifier" => status_identifier,
          "loan_file_id" => loan_file_id
        },
        session_data
      ) do
    loan_file = Repo.get_by(LoanFiles, id: loan_file_id, active: true)

    case loan_file do
      nil ->
        {:error, "Loan file does not exist"}

      loan_file ->
        case update_loan_file_details(params, loan_file) do
          {:ok, _changeset} ->
            broker_id = session_data |> get_in(["profile", "broker_id"])
            status_id = Status.get_status_id_from_identifier(status_identifier)

            same_status_exists =
              LoanFileStatus
              |> where([lfs], lfs.loan_file_id == ^loan_file_id and lfs.status_id == ^status_id)
              |> Repo.all()

            if length(same_status_exists) == 0, do: LoanFileStatus.create_loan_file_status(loan_file, status_id, params["note"])

            if is_loan_file_ahead_of_all(loan_file.homeloan_lead_id, status_identifier) and check_failed_scenarios(status_identifier, params["lead_id"]) do
              Homeloans.update_lead_status_for_dsa(params, broker_id, "V2")
            else
              {:ok, "Loan File updated"}
            end

          {:error, error} ->
            {:error, error}
        end
    end
  end

  def check_failed_scenarios(status_identifier, _lead_id) when status_identifier != "FAILED", do: true

  def check_failed_scenarios(_status_identifier, lead_id) do
    if has_lead_non_failed_files(lead_id), do: false, else: true
  end

  def has_lead_non_failed_files(lead_id) do
    count =
      LoanFiles
      |> join(:inner, [lf], lfs in LoanFileStatus, on: lf.latest_file_status_id == lfs.id)
      # 8 is failed
      |> where([lf, lfs], lf.homeloan_lead_id == ^lead_id and lf.active == true and lfs.status_id != 8)
      |> Repo.aggregate(:count, :id)

    count > 0
  end

  def get_loan_files(lead_id, is_admin \\ true) do
    LoanFiles
    |> where([lf], lf.homeloan_lead_id == ^lead_id and lf.active == ^true)
    |> order_by([lf], desc: lf.inserted_at)
    |> preload(:latest_file_status)
    |> Repo.all()
    |> Enum.map(fn loan_file ->
      bank_logo_url = Bank.get_bank_logo_url_from_id(loan_file.bank_id)
      disbursements = LoanDisbursement.get_loan_disbursements_for_file_id(loan_file.id)
      total_disbursed_amt = disbursements |> Enum.reduce(0, fn dis, acc -> acc + (dis.loan_disbursed || 0) end)

      total_commission_amt =
        disbursements
        |> Enum.filter(& &1.loan_commission_paid)
        |> Enum.reduce(0, fn dis, acc -> acc + (dis.loan_commission || 0) end)

      %{
        loan_file_id: loan_file.id,
        status_id: loan_file.latest_file_status.status_id,
        bank_id: loan_file.bank_id,
        bank_name: Bank.get_bank_name_from_id(loan_file.bank_id),
        bank_logo_url: if(is_nil(bank_logo_url), do: S3Helper.get_imgix_url("assets/default_bank_logo.png"), else: S3Helper.get_imgix_url(bank_logo_url)),
        branch_location: loan_file.branch_location,
        status_identifier: Status.get_status_from_id(loan_file.latest_file_status.status_id)["identifier"],
        application_id: loan_file.application_id,
        bank_rm_name: loan_file.bank_rm_name,
        bank_rm_phone_number: loan_file.bank_rm_phone_number,
        sanctioned_amount: loan_file.sanctioned_amount,
        display_sanctioned_amount: Utils.format_money_new(loan_file.sanctioned_amount),
        sanctioned_doc_url: S3Helper.get_imgix_url(loan_file.sanctioned_doc_url),
        sanctioned_doc_key: loan_file.sanctioned_doc_url,
        s3_prefix_url: ApplicationHelper.get_imgix_domain(),
        bank_offer_doc_key: loan_file.bank_offer_doc_url,
        bank_offer_doc_url: S3Helper.get_imgix_url(loan_file.bank_offer_doc_url),
        original_agreement_doc_url: S3Helper.get_imgix_url(loan_file.original_agreement_doc_url),
        loan_insurance_done: loan_file.loan_insurance_done,
        loan_insurance_amount: loan_file.loan_insurance_amount,
        display_loan_insurance_amount: Utils.format_money_new(loan_file.loan_insurance_amount),
        disbursements: disbursements,
        inserted_at: loan_file.inserted_at |> Time.naive_to_epoch_in_sec(),
        total_disbursed_amt: total_disbursed_amt,
        total_commission_amt: total_commission_amt
      }
      |> maybe_append_keys_for_app(loan_file, is_admin)
    end)
  end

  def maybe_append_keys_for_app(response, _loan_file, true), do: response

  def maybe_append_keys_for_app(response, loan_file, _) do
    current_status = %{
      "status_name" => Status.get_status_from_id(loan_file.latest_file_status.status_id)["display_name"],
      "status_identifier" => Status.get_status_from_id(loan_file.latest_file_status.status_id)["identifier"],
      "status_id" => loan_file.latest_file_status.status_id,
      "bg_color_code" => Status.get_status_from_id(loan_file.latest_file_status.status_id)["bg_color_code"],
      "text_color_code" => Status.get_status_from_id(loan_file.latest_file_status.status_id)["text_color_code"]
    }

    Map.put(response, "current_status", current_status)
  end

  def get_sanctioned_letter_from_loan_files(lead_id) do
    LoanFiles
    |> where([lf], lf.homeloan_lead_id == ^lead_id and lf.active == ^true and not is_nil(lf.sanctioned_doc_url))
    |> order_by([lf], desc: lf.inserted_at)
    |> Repo.all()
    |> Enum.map(fn loan_file ->
      bank_logo_url = Bank.get_bank_logo_url_from_id(loan_file.bank_id)

      %{
        bank_name: Bank.get_bank_name_from_id(loan_file.bank_id),
        bank_logo_url: if(is_nil(bank_logo_url), do: S3Helper.get_imgix_url("assets/default_bank_logo.png"), else: S3Helper.get_imgix_url(bank_logo_url)),
        application_id: loan_file.application_id,
        branch_location: loan_file.branch_location,
        doc_url: S3Helper.get_imgix_url(loan_file.sanctioned_doc_url),
        doc_name: "Sanctioned Letter",
        doc_type_name: "Sanctioned Letter",
        doc_id: 0,
        allow_delete: false,
        loan_file_id: loan_file.id,
        inserted_at: loan_file.inserted_at |> Time.naive_to_epoch_in_sec()
      }
    end)
  end

  def get_loan_file(loan_file_id) do
    Repo.get_by(LoanFiles, id: loan_file_id, active: true)
  end

  def update_latest_loan_file_status(%LoanFiles{} = loan_file, latest_loan_file_status_id) do
    ch =
      LoanFiles.changeset(loan_file, %{
        latest_file_status_id: latest_loan_file_status_id
      })

    Repo.update!(ch)
  end

  def get_all_loan_files(lead_id) do
    LoanFiles
    |> join(:inner, [l], lf in LoanFileStatus, on: l.latest_file_status_id == lf.id)
    |> join(:inner, [l, lf], b in Bank, on: l.bank_id == b.id)
    |> where([l, lf, b], l.homeloan_lead_id == ^lead_id and l.active == true)
    |> select([l, lf, b], %{
      bank_id: l.bank_id,
      loan_file_status_id: lf.status_id,
      latest_file_status_id: l.latest_file_status_id,
      bank_name: b.name
    })
    |> Repo.all()
  end
end
