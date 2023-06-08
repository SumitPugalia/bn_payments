defmodule BnApis.Accounts.ProfileType do
  use Ecto.Schema
  import Ecto.Changeset

  # BROKER
  @broker %{id: 1, name: "Broker"}
  # EMPLOYEE
  @employee %{id: 2, name: "Employee"}
  # DEVELOPER
  @developer %{id: 3, name: "Developer"}
  # DEVELOPER POC
  @developer_poc %{id: 4, name: "Developer POC"}
  # Legal Entity POC - Admin
  @legal_entity_poc_admin %{id: 5, name: "Legal Entity POC Admin"}
  # Legal Entity POC
  @legal_entity_poc %{id: 6, name: "Legal Entity POC"}

  def seed_data do
    [
      @broker,
      @employee,
      @developer,
      @legal_entity_poc_admin,
      @legal_entity_poc
    ]
  end

  @primary_key false
  schema "credentials_profile_types" do
    field :id, :integer, primary_key: true
    field :name, :string

    timestamps()
  end

  @doc false
  def changeset(profile_type, params) do
    profile_type
    |> cast(params, [:id, :name])
    |> validate_required([:id, :name])
    |> unique_constraint(:name)
  end

  def changeset(params) do
    %__MODULE__{}
    |> changeset(params)
  end

  def broker do
    @broker
  end

  def employee do
    @employee
  end

  def developer do
    @developer
  end

  def developer_poc do
    @developer_poc
  end

  def legal_entity_poc, do: @legal_entity_poc
  def legal_entity_poc_admin, do: @legal_entity_poc_admin

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
end
