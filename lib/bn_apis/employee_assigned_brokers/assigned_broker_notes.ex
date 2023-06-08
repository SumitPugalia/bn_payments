defmodule BnApis.AssignedBrokerNotes do
  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query

  alias BnApis.{Repo, AssignedBrokers, AssignedBrokerNotes}
  alias BnApis.Helpers.Time

  schema "employees_assigned_brokers_notes" do
    field :type, :string, default: "Text"
    field :data, :string

    belongs_to :employees_assigned_brokers, AssignedBrokers
    timestamps()
  end

  @fields [:type, :data, :employees_assigned_brokers_id]
  @required_fields [:employees_assigned_brokers_id, :data]

  def changeset(assigned_broker_note, attrs \\ %{}) do
    assigned_broker_note
    |> cast(attrs, @fields)
    |> validate_required(@required_fields)
    |> foreign_key_constraint(:employees_assigned_brokers_id)
  end

  def create(params) do
    %AssignedBrokerNotes{}
    |> AssignedBrokerNotes.changeset(params)
    |> Repo.insert()
  end

  def update(assigned_broker_note, params) do
    assigned_broker_note
    |> AssignedBrokerNotes.changeset(params)
    |> Repo.update()
  end

  def fetch_all_notes(employees_assigned_brokers_id) do
    AssignedBrokerNotes
    |> where([abn], abn.employees_assigned_brokers_id == ^employees_assigned_brokers_id)
    |> order_by([abn], desc: abn.inserted_at)
    |> select([abn], %{
      data: abn.data,
      type: abn.type,
      inserted_at: abn.inserted_at
    })
    |> Repo.all()
    |> process_response()
  end

  defp process_response(data) do
    data
    |> Enum.map(&put_in(&1, [:inserted_at], &1[:inserted_at] |> Time.naive_to_epoch()))
  end
end
