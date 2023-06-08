defmodule BnApis.Accounts.OwnersBrokerEmployeeMapping do
  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query

  alias BnApis.Repo
  alias BnApis.Accounts.EmployeeCredential
  alias BnApis.Organizations.Broker
  alias BnApis.Accounts.OwnersBrokerEmployeeMapping

  schema "owners_broker_employee_mappings" do
    field(:active, :boolean, default: false)

    belongs_to :employees_credentials, EmployeeCredential
    belongs_to :assigned_by, EmployeeCredential
    belongs_to :broker, Broker

    timestamps()
  end

  @fields [:employees_credentials_id, :active, :broker_id, :assigned_by_id]

  @doc false
  def changeset(obem, attrs \\ %{}) do
    obem
    |> cast(attrs, @fields)
    |> validate_required(@fields)
    |> unique_constraint(:unique_obem_req,
      name: :owners_broker_employee_mappings_uniq_index,
      message: "active broker employee mapping exists"
    )
  end

  def create_owners_broker_employee_mapping(employees_credentials_id, broker_id, assigned_by_id) do
    Repo.transaction(fn ->
      try do
        OwnersBrokerEmployeeMapping
        |> where([ob], ob.broker_id == ^broker_id)
        |> Repo.all()
        |> Enum.each(fn obm ->
          obm |> OwnersBrokerEmployeeMapping.changeset(%{"active" => false}) |> Repo.update!()
        end)

        obem_changeset =
          changeset(%OwnersBrokerEmployeeMapping{}, %{
            "employees_credentials_id" => employees_credentials_id,
            "active" => true,
            "broker_id" => broker_id,
            "assigned_by_id" => assigned_by_id
          })

        obem_changeset |> Repo.insert!()
      rescue
        err ->
          Repo.rollback(Exception.message(err))
      end
    end)
  end
end
