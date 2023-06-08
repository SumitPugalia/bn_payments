defmodule BnApis.Homeloan.HLCallLeadStatus do
  use Ecto.Schema
  import Ecto.Changeset

  alias BnApis.Repo
  alias BnApis.Calls
  alias BnApis.Homeloan.HLCallLeadStatus
  alias BnApis.Homeloan.Lead

  schema "homeloans_call_lead_statuses" do
    field(:lead_status_id, :integer)
    belongs_to(:call_details, Calls)

    timestamps()
  end

  @required [:lead_status_id, :call_details_id]

  @doc false
  def changeset(lead_status_note, attrs) do
    lead_status_note
    |> cast(attrs, @required)
    |> validate_required(@required)
    |> foreign_key_constraint(:call_details_id)
  end

  def save_lead_status(call_details_id, lead_id) do
    lead = Lead.get_homeloan_lead(lead_id) |> Repo.preload(:latest_lead_status)
    latest_status_id = lead.latest_lead_status.status_id

    changeset =
      HLCallLeadStatus.changeset(%HLCallLeadStatus{}, %{
        lead_status_id: latest_status_id,
        call_details_id: call_details_id
      })

    Repo.insert(changeset)
  end
end
