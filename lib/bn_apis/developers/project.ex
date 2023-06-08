defmodule BnApis.Developers.Project do
  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query
  alias BnApis.Developers.{Project, Developer, SalesPerson}
  alias BnApis.Repo

  @hot_projects_limit 5

  schema "projects" do
    field(:display_address, :string)
    field(:name, :string)
    field(:uuid, Ecto.UUID, read_after_writes: true)
    field(:hot, :boolean)
    belongs_to(:developer, Developer)

    has_many(:sales_persons, SalesPerson)
    timestamps()
  end

  @doc false
  def changeset(project, attrs) do
    project
    |> cast(attrs, [:uuid, :name, :display_address, :developer_id, :hot])
    |> validate_required([:name])
  end

  def changeset(attrs) do
    %__MODULE__{}
    |> changeset(attrs)
  end

  def create_project(attrs) do
    %Project{}
    |> Project.changeset(attrs)
    |> Repo.insert()
  end

  def get_by_uuid_query(uuid) do
    Project
    |> where(uuid: ^uuid)
    |> preload([:sales_persons])
  end

  def get_ids_from_uids_query(uids) do
    Project
    |> where([p], p.uuid in ^uids)
  end

  @doc """
  Fetch hot projects in random order
  """
  def fetch_hot_projects(limit \\ @hot_projects_limit) do
    Project
    |> where([p], p.hot == true)
    |> order_by(fragment("RANDOM()"))
    |> limit(^limit)
    |> select(
      [p],
      %{
        name: p.name,
        uuid: p.uuid
      }
    )
    |> Repo.all()
  end

  def search_project_query(search_text, exclude_project_uuids) do
    modified_search_text = "%" <> search_text <> "%"

    Project
    |> join(:inner, [p], dev in assoc(p, :developer))
    |> where([p, dev], p.uuid not in ^exclude_project_uuids)
    |> where(
      [p, dev],
      ilike(p.name, ^modified_search_text) or
        ilike(dev.name, ^modified_search_text)
    )
    |> order_by(
      [p, dev],
      fragment(
        "lower(?) <-> ?, lower(?) <-> ?",
        p.name,
        ^search_text,
        dev.name,
        ^search_text
      )
    )
    |> limit(5)
    |> select(
      [p, dev],
      %{
        id: p.uuid,
        project_id: p.id,
        uuid: p.uuid,
        name: p.name,
        developer_name: dev.name,
        display_address: p.display_address
      }
    )
  end
end
