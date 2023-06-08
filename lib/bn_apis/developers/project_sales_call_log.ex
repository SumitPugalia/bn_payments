defmodule BnApis.Developers.ProjectSalesCallLog do
  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query

  alias BnApis.Developers.{ProjectSalesCallLog, SalesPerson}
  alias BnApis.Repo

  schema "project_sales_call_logs" do
    field :timestamp, :naive_datetime
    field :uuid, Ecto.UUID, read_after_writes: true
    field :user_id, :id
    belongs_to :sales_person, SalesPerson

    timestamps()
  end

  @required [:sales_person_id, :user_id, :timestamp]
  @fields @required ++ []

  @doc false
  def changeset(project_sales_call_log, attrs) do
    project_sales_call_log
    |> cast(attrs, @fields)
    |> validate_required(@required)
  end

  def sales_call_logs_query(user_id) do
    ProjectSalesCallLog
    |> where(user_id: ^user_id)
    |> order_by([log], desc: log.timestamp)
    |> limit(5)
    |> preload(sales_person: [:project])
  end

  def get_user_recent_call_to(user_id) do
    ProjectSalesCallLog
    |> where(user_id: ^user_id)
    |> order_by([log], desc: log.timestamp)
    |> limit(1)
    |> select([log], log.sales_person_id)
    |> Repo.all()
    |> List.first()
  end
end
