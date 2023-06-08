defmodule BnApis.Developers.SiteVisit do
  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query
  alias BnApis.Repo
  alias BnApis.Developers.{SiteVisit, Project}
  alias BnApis.Accounts.{Credential, DeveloperCredential}
  alias BnApis.Organizations.Organization
  alias BnApis.Helpers.FormHelper

  schema "site_visits" do
    field :time_of_visit, :naive_datetime
    field :lead_reference, :string
    field :lead_reference_name, :string
    field :lead_reference_email, :string
    field :broker_phone_number, :string
    field :broker_name, :string
    field :broker_email, :string

    belongs_to :reported_by, DeveloperCredential
    belongs_to :visited_by, Credential
    belongs_to :old_visited_by, Credential
    belongs_to :old_organization_id, Organization
    belongs_to :project, Project

    timestamps()
  end

  @fields [
    :time_of_visit,
    :project_id,
    :reported_by_id,
    :visited_by_id,
    :lead_reference,
    :broker_name,
    :broker_email,
    :broker_phone_number,
    :lead_reference_email,
    :lead_reference_name,
    :old_visited_by,
    :old_organization_id
  ]
  @required_fields [:time_of_visit, :project_id, :reported_by_id]

  @doc false
  def changeset(site_visit, attrs) do
    site_visit
    |> cast(attrs, @fields)
    |> validate_required(@required_fields)
    |> foreign_key_constraint(:project_id)
    |> foreign_key_constraint(:reported_by_id)
    |> foreign_key_constraint(:visited_by_id)
    |> FormHelper.validate_site_visit()
  end

  def create(attrs) do
    %SiteVisit{}
    |> SiteVisit.changeset(attrs)
    |> Repo.insert()
  end

  def migrate_credential(from_id, to_id) do
    Repo.update_all(from(s in SiteVisit, where: s.visited_by_id == ^from_id, update: [set: [visited_by_id: ^to_id]]), [])
  end
end
