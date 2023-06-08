defmodule BnApis.Organizations.BrokerOrganization do
  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query

  alias BnApis.Organizations.{Broker, BrokerRole, Organization}

  schema "brokers_organizations" do
    field :active, :boolean, default: true
    field :last_active_at, :naive_datetime

    belongs_to :organization, Organization
    belongs_to :broker_role, BrokerRole
    belongs_to :broker, Broker

    timestamps()
  end

  @fields [:active, :last_active_at, :organization_id, :broker_role_id, :broker_id]
  @required_fields [:organization_id, :broker_role_id, :broker_id]

  @doc false
  def changeset(broker_organization, attrs \\ %{}) do
    broker_organization
    |> cast(attrs, @fields)
    |> validate_required(@required_fields)
    |> foreign_key_constraint(:organization_id)
    |> foreign_key_constraint(:broker_role_id)
    |> foreign_key_constraint(:broker_id)
    |> unique_constraint(:org_broker_uniq, name: :brokers_organizations_ids_org_broker_index)
  end

  def activate_changeset(broker_organization) do
    broker_organization
    |> changeset
    |> change(active: true)
  end

  def deactivate_changeset(broker_organization) do
    broker_organization
    |> changeset
    |> change(active: false)
  end

  def broker_role_changeset(broker_organization, broker_role_id) do
    broker_organization
    |> changeset
    |> change(broker_role_id: broker_role_id)
  end

  def promote_changeset(broker_organization) do
    broker_organization
    |> changeset
    |> change(broker_role_id: BrokerRole.admin().id)
  end

  def demote_changeset(broker_organization) do
    broker_organization
    |> changeset
    |> change(broker_role_id: BrokerRole.chhotus().id)
  end

  def update_last_active_at_query(id) do
    __MODULE__
    |> where(id: ^id)
    |> Ecto.Query.update(set: [last_active_at: fragment("date_trunc('second',now() AT TIME ZONE 'UTC')")])
  end
end
