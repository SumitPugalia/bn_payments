defmodule BnApis.CallLogs.AssignedBrokerCallLogs do
  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query
  alias BnApis.CallLogs.AssignedBrokerCallLogs
  alias BnApis.AssignedBrokers
  alias BnApis.Repo
  alias BnApis.Helpers.Time

  schema "employees_assigned_brokers_call_logs" do
    field :uuid, Ecto.UUID, read_after_writes: true

    belongs_to :employees_assigned_brokers, AssignedBrokers
    timestamps()
  end

  @required [:employees_assigned_brokers_id]
  @fields @required ++ []

  @doc false
  def changeset(call_log, attrs) do
    call_log
    |> cast(attrs, @fields)
    |> validate_required(@required)
    |> foreign_key_constraint(:employees_assigned_brokers_id)
  end

  def create(params) do
    %AssignedBrokerCallLogs{}
    |> AssignedBrokerCallLogs.changeset(params)
    |> Repo.insert()
  end

  def fetch_all_call_logs(employees_assigned_brokers_id) do
    AssignedBrokerCallLogs
    |> where([ab], ab.employees_assigned_brokers_id == ^employees_assigned_brokers_id)
    |> order_by([ab], desc: ab.inserted_at)
    |> select([ab], %{
      type: "Dialed",
      data: "Dialed",
      inserted_at: ab.inserted_at
    })
    |> Repo.all()
    |> process_response()
  end

  defp process_response(data) do
    data
    |> Enum.map(&put_in(&1, [:inserted_at], &1[:inserted_at] |> Time.naive_to_epoch()))
  end
end
