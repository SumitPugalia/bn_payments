defmodule BnApis.Organizations.BrokerRole do
  use Ecto.Schema
  import Ecto.Changeset

  # ADMIN
  @admin %{id: 1, name: "Admin"}
  # ASSISTANT
  @chhotus %{id: 2, name: "Assistant"}

  def seed_data do
    [
      @admin,
      @chhotus
    ]
  end

  @primary_key false
  schema "brokers_roles" do
    field :id, :integer, primary_key: true
    field :name, :string

    timestamps()
  end

  @doc false
  def changeset(broker_role, params) do
    broker_role
    |> cast(params, [:id, :name])
    |> validate_required([:id, :name])
    |> unique_constraint(:name)
  end

  def changeset(params) do
    %__MODULE__{}
    |> changeset(params)
  end

  def admin do
    @admin
  end

  def chhotus do
    @chhotus
  end

  def get_by_id(id) do
    seed_data()
    |> Enum.filter(&(&1.id == id))
    |> List.first()
  end

  def get_by_name(ats_role_name) do
    seed_data()
    |> Enum.filter(&(&1.name == ats_role_name))
    |> List.first()
  end

  def get_by_ext_name(ext_name) do
    case ext_name do
      "ADMIN" ->
        @admin

      "ASSISTANT" ->
        @chhotus
    end
  end
end
