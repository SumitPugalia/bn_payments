defmodule BnApis.Homeloan.LeadStatusNote do
  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query

  alias BnApis.Repo
  alias BnApis.Homeloan.Status
  alias BnApis.Homeloan.LeadStatus
  alias BnApis.Homeloan.LeadStatusNote
  alias BnApis.Accounts.EmployeeCredential
  alias BnApis.Helpers.Time

  schema "homeloan_lead_status_notes" do
    field(:note, :string)
    belongs_to(:homeloan_lead_status, LeadStatus)
    belongs_to(:employee_credential, EmployeeCredential)

    timestamps()
  end

  @required [:note, :homeloan_lead_status_id]
  @optional [:employee_credential_id]

  @doc false
  def changeset(lead_status_note, attrs) do
    lead_status_note
    |> cast(attrs, @required ++ @optional)
    |> validate_required(@required)
    |> foreign_key_constraint(:homeloan_lead_status_id)
    |> foreign_key_constraint(:employee_credential_id)
  end

  def create_lead_status_note!(note, lead_status_id, employee_credential_id) do
    changeset =
      LeadStatusNote.changeset(%LeadStatusNote{}, %{
        note: note,
        homeloan_lead_status_id: lead_status_id,
        employee_credential_id: employee_credential_id
      })

    Repo.insert!(changeset)
  end

  def get_details(lead_status_note, description) do
    status = Status.status_list()[lead_status_note.homeloan_lead_status.status_id]

    %{
      "status" => status["identifier"],
      "text" => lead_status_note.note,
      "updated_at" => lead_status_note.inserted_at,
      "updated_at_unix" => Time.naive_to_epoch_in_sec(lead_status_note.inserted_at),
      "created_by" => EmployeeCredential.get_employee_name(lead_status_note.employee_credential_id),
      "description" => description
    }
  end

  def get_notes_by_lead_id(lead_id) do
    LeadStatusNote
    |> join(:inner, [l], ls in LeadStatus, on: ls.id == l.homeloan_lead_status_id)
    |> join(:inner, [l, ls], e in EmployeeCredential, on: l.employee_credential_id == e.id)
    |> where([l, ls, e], ls.homeloan_lead_id == ^lead_id)
    |> select([l, ls, e], %{
      homeloan_lead_id: ls.homeloan_lead_id,
      status_id: ls.status_id,
      homeloan_lead_status_id: l.homeloan_lead_status_id,
      note: l.note,
      employee_credential_id: l.employee_credential_id,
      updated_at: l.updated_at,
      updated_by: e.name
    })
    |> Repo.all()
    |> Enum.map(fn note ->
      note
      |> Map.merge(%{
        updated_at: Time.naive_to_epoch_in_sec(note.updated_at),
        status: Status.get_status_from_id(note.status_id)["identifier"]
      })
    end)
  end
end
