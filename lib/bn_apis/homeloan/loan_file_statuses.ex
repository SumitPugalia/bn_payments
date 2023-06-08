defmodule BnApis.Homeloan.LoanFileStatus do
  use Ecto.Schema
  import Ecto.Changeset
  # import Ecto.Query

  alias BnApis.Repo
  # alias BnApis.Homeloan.Lead
  alias BnApis.Homeloan.LoanFiles
  alias BnApis.Homeloan.LoanFileStatus

  schema "loan_file_statuses" do
    field(:status_id, :integer)
    field(:note, :string)
    belongs_to(:loan_file, LoanFiles)
    belongs_to(:employee_credential, EmployeeCredential)

    timestamps()
  end

  @required [:status_id, :loan_file_id]
  @optional [:employee_credential_id, :note]

  @doc false
  def changeset(lead_status, attrs) do
    lead_status
    |> cast(attrs, @required ++ @optional)
    |> validate_required(@required)
    |> foreign_key_constraint(:homeloan_lead_id)
    |> foreign_key_constraint(:employee_credential_id)
  end

  def get_loan_file_status(id) do
    Repo.get_by(LeadStatus, id: id)
  end

  def create_loan_file_status(
        loan_file,
        status_id,
        note,
        employee_credential_id \\ nil
      ) do
    changeset =
      LoanFileStatus.changeset(%LoanFileStatus{}, %{
        loan_file_id: loan_file.id,
        status_id: status_id,
        employee_credential_id: employee_credential_id,
        note: note
      })

    loan_file_status = Repo.insert!(changeset)
    LoanFiles.update_latest_loan_file_status(loan_file, loan_file_status.id)
    loan_file_status
  end

  def get_file_statuses_of_lead(lead) do
    lead = Repo.preload(lead, :loan_files)

    Enum.reduce(lead.loan_files, [], fn loan_file, acc ->
      loan_file = Repo.preload(loan_file, :loan_file_statuses)
      acc ++ loan_file.loan_file_statuses
    end)
  end
end
