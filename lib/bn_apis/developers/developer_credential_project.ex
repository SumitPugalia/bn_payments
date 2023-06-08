defmodule BnApis.Developers.DeveloperCredentialProject do
  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query

  alias BnApis.Repo
  alias BnApis.Developers.{Project, DeveloperCredentialProject}
  alias BnApis.Accounts.DeveloperCredential

  schema "developers_credentials_projects" do
    field :active, :boolean, default: true
    field :uuid, Ecto.UUID, read_after_writes: true

    belongs_to :developers_credentials, DeveloperCredential
    belongs_to :project, Project

    timestamps()
  end

  @fields [:active, :project_id, :developers_credentials_id]
  @required_fields [:project_id, :developers_credentials_id]

  @doc false
  def changeset(developer_credential_project, attrs) do
    developer_credential_project
    |> cast(attrs, @fields)
    |> validate_required(@required_fields)
  end

  def create(attrs) do
    %DeveloperCredentialProject{}
    |> DeveloperCredentialProject.changeset(attrs)
    |> Repo.insert()
  end

  def get_active_projects(developers_credentials_id) do
    DeveloperCredentialProject
    |> join(:inner, [dcp], p in Project, on: dcp.project_id == p.id)
    |> where([dcp, p], dcp.developers_credentials_id == ^developers_credentials_id)
    |> where([dcp, p], dcp.active == true)
    |> select([dcp, p], %{
      project_uuid: p.uuid,
      project_name: p.name
    })
    |> Repo.all()
  end
end
