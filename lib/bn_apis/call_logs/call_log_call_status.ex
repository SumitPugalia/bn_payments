defmodule BnApis.CallLogs.CallLogCallStatus do
  use Ecto.Schema
  import Ecto.Changeset

  @missed %{id: 1, name: "Missed Call"}
  @incoming %{id: 2, name: "Incoming Call"}
  @outgoing %{id: 3, name: "Outgoing Call"}

  def seed_data do
    [
      @missed,
      @incoming,
      @outgoing
    ]
  end

  @primary_key false
  schema "call_logs_call_statuses" do
    field :id, :integer, primary_key: true
    field :name, :string

    timestamps()
  end

  @doc false
  def changeset(call_log_call_status, params) do
    call_log_call_status
    |> cast(params, [:id, :name])
    |> validate_required([:id, :name])
    |> unique_constraint(:name)
  end

  @doc false
  def changeset(params) do
    %__MODULE__{}
    |> changeset(params)
  end

  def missed do
    @missed
  end

  def incoming do
    @incoming
  end

  def outgoing do
    @outgoing
  end

  def get_by_id(id) do
    seed_data()
    |> Enum.filter(&(&1.id == id))
    |> List.first()
  end

  def get_by_name(name) do
    seed_data()
    |> Enum.filter(&(&1.name == name))
    |> List.first()
  end
end
