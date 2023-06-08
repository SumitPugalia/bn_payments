defmodule BnApis.AssignedBrokers do
  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query

  alias BnApis.{Repo, AssignedBrokers, Accounts}
  alias BnApis.Accounts.{Credential, EmployeeCredential, EmployeeVertical}
  alias BnApis.Organizations.{Broker, Organization}
  alias BnApis.Places.Polygon
  alias BnApis.Helpers.{Utils, Time, S3Helper, AssignedBrokerHelper}

  schema "employees_assigned_brokers" do
    field :active, :boolean, default: true
    field :assigned_by_id, :integer
    field :snoozed, :boolean, default: false
    field :snoozed_till, :naive_datetime
    field :is_marked_lost, :boolean, default: false
    field :lost_reason, :string
    field :channel_url, :string

    belongs_to :broker, Broker
    belongs_to :employees_credentials, EmployeeCredential
    timestamps()
  end

  @fields [
    :active,
    :assigned_by_id,
    :broker_id,
    :employees_credentials_id,
    :snoozed,
    :snoozed_till,
    :is_marked_lost,
    :lost_reason,
    :channel_url
  ]
  @required_fields [:active, :broker_id, :employees_credentials_id]

  def changeset(assigned_broker, attrs \\ %{}) do
    assigned_broker
    |> cast(attrs, @fields)
    |> validate_required(@required_fields)
    |> foreign_key_constraint(:assigned_by_id)
  end

  def update(assigned_broker, params) do
    assigned_broker
    |> AssignedBrokers.changeset(params)
    |> Repo.update()
  end

  def create_employee_assignments(assigned_by_id, employee_credential_id, broker_ids) do
    broker_ids |> Enum.map(&create_assignment(assigned_by_id, employee_credential_id, &1))
  end

  def remove_employee_assignments(_assigned_by_id, employee_credential_id, broker_ids) do
    broker_ids |> Enum.map(&remove_assignment(employee_credential_id, &1))
  end

  def create_assignment(assigned_by_id, employee_credential_id, broker_id) do
    case AssignedBrokers.fetch_employee_broker(employee_credential_id, broker_id) do
      nil ->
        %AssignedBrokers{}
        |> AssignedBrokers.changeset(%{
          assigned_by_id: assigned_by_id,
          employees_credentials_id: employee_credential_id,
          broker_id: broker_id
        })
        |> Repo.insert!()

      employee_broker ->
        employee_broker |> change(active: true) |> Repo.update!()
    end
  end

  def remove_assignment(employee_credential_id, broker_id) do
    case fetch_employee_brokers(employee_credential_id, broker_id) do
      nil ->
        {:error, "No such mapping found"}

      _ ->
        AssignedBrokers
        |> where([ab], ab.broker_id == ^broker_id and ab.employees_credentials_id == ^employee_credential_id and ab.active == ^true)
        |> Repo.update_all(set: [active: false])
    end
  end

  def remove_all_assignments(broker_id) do
    AssignedBrokers
    |> where([ab], ab.broker_id == ^broker_id and ab.active == true)
    |> Repo.update_all(set: [active: false])
  end

  def fetch_assigned_brokers(broker_ids) do
    AssignedBrokers
    |> where([ab], ab.active == true and ab.broker_id in ^broker_ids)
    |> Repo.all()
  end

  def fetch_assigned_broker(broker_id) do
    AssignedBrokers
    |> where([ab], ab.broker_id == ^broker_id and ab.active == true)
    |> order_by([ab], desc: ab.updated_at)
    |> limit(1)
    |> Repo.one()
  end

  def fetch_employee_broker(employee_credential_id, broker_ids) when is_list(broker_ids) do
    AssignedBrokers
    |> where([ab], ab.employees_credentials_id == ^employee_credential_id and ab.broker_id in ^broker_ids)
    |> Repo.all()
  end

  def fetch_employee_broker(employee_credential_id, broker_id) do
    AssignedBrokers
    |> where([ab], ab.employees_credentials_id == ^employee_credential_id and ab.broker_id == ^broker_id)
    |> Repo.one()
  end

  def fetch_employee_brokers(employee_credential_id, broker_id) do
    AssignedBrokers
    |> where([ab], ab.employees_credentials_id == ^employee_credential_id and ab.broker_id == ^broker_id)
    |> Repo.all()
  end

  def fetch_vertical_broker(vertical_id, broker_id) do
    AssignedBrokers
    |> join(:inner, [ab], e in EmployeeCredential, on: e.id == ab.employees_credentials_id and e.vertical_id == ^vertical_id and e.active == true)
    |> where([ab, e], ab.broker_id == ^broker_id and ab.active == true)
    |> Repo.one()
  end

  def fetch_one_broker(broker_id, vertical) when vertical not in [nil, ""] do
    vertical_id = EmployeeVertical.get_vertical_by_identifier(vertical)["id"]
    broker = fetch_vertical_broker(vertical_id, broker_id)

    case broker do
      nil ->
        vertical_id = EmployeeVertical.default_vertical_id()
        fetch_vertical_broker(vertical_id, broker_id)

      broker ->
        broker
    end
  end

  def fetch_one_broker(broker_id) do
    AssignedBrokers
    |> where([a], a.broker_id == ^broker_id and a.active == true)
    |> last()
    |> Repo.one()
  end

  # fetch all active assigned brokers
  def fetch_all_active_assigned_brokers(employee_credential_id) do
    AssignedBrokers
    |> where([ab], ab.active == true and ab.employees_credentials_id == ^employee_credential_id)
    |> select([ab], ab.broker_id)
    |> Repo.all()
  end

  def fetch_all_assigned_brokers() do
    AssignedBrokers
    |> where([ab], ab.active == true)
    |> select([ab], ab.broker_id)
    |> distinct(:broker_id)
    |> Repo.all()
  end

  # fetch all unassigned brokers
  def fetch_all_unassigned_brokers() do
    assigned_broker_ids = fetch_all_assigned_brokers()

    Credential
    |> join(:inner, [c], o in Organization, on: o.id == c.organization_id)
    |> join(:inner, [c, o, b], b in Broker, on: b.id == c.broker_id)
    |> where([c, o, b], c.active == true and c.broker_id not in ^assigned_broker_ids)
    |> select([c, o, b], %{
      org_uuid: o.uuid,
      org_name: o.name,
      org_id: o.id,
      firm_address: o.firm_address,
      broker_name: b.name,
      phone_number: c.phone_number,
      polygon_id: b.polygon_id,
      operating_city: b.operating_city,
      broker_id: b.id
    })
    |> Repo.all()
  end

  def fetch_all_assignees_info(org_brokers) do
    AssignedBrokers
    |> join(:inner, [ab], e in EmployeeCredential, on: e.id == ab.employees_credentials_id)
    |> where([ab, e], ab.active == true and ab.broker_id in ^org_brokers)
    |> select([ab, e], %{
      employee_id: e.id,
      employee_credential_uuid: e.uuid,
      employee_name: e.name,
      employee_phone_number: e.phone_number,
      broker_id: ab.broker_id,
      vertical_id: e.vertical_id,
      assigned_id: ab.id
    })
    |> Repo.all()
  end

  def assigned_broker_details(broker_ids) do
    Credential
    |> where(active: true)
    |> Credential.select_query(broker_ids)
    |> Repo.all()
  end

  def assigned_broker_data(broker_ids) do
    broker_ids
    |> assigned_broker_details()
    |> Enum.map(fn broker_details ->
      profile_image =
        case broker_details.profile_image do
          nil -> nil
          %{"url" => nil} -> nil
          %{"url" => url} -> S3Helper.get_imgix_url(url)
        end

      %{
        phone_number: broker_details.phone_number,
        last_activity: broker_details.last_active_at |> Time.naive_to_epoch(),
        name: broker_details.name,
        org_name: broker_details.org_name,
        org_uuid: broker_details.org_uuid,
        gst_number: broker_details.gst_number,
        rera_id: broker_details.rera_id,
        broker_id: broker_details.broker_id,
        broker_type_id: broker_details.broker_type_id,
        profile_pic_url: profile_image,
        user_id: broker_details.id,
        firm_address: broker_details.firm_address,
        polygon_id: broker_details.polygon_id,
        uninstalled: Accounts.uninstalled?(broker_details),
        uuid: broker_details.uuid
      }
    end)
  end

  def dashboard_assigned_broker_data(employee_credential_id, broker_ids) do
    assigned_brokers =
      employee_credential_id
      |> fetch_employee_broker(broker_ids)
      |> Enum.reject(&is_nil(&1))

    brokers_data = assigned_broker_data(Enum.map(assigned_brokers, fn assigned_broker -> assigned_broker.broker_id end))

    assigned_brokers
    |> Enum.zip(brokers_data)
    |> Enum.map(fn {assigned_broker, broker_data} ->
      assigned_broker |> add_broker_info(broker_data)
    end)
    |> Enum.reject(&is_nil(&1))
  end

  def add_broker_info(assigned_broker, _data) when is_nil(assigned_broker), do: nil

  def add_broker_info(assigned_broker, data) do
    data
    # |> Map.merge(ActivityHelper.last_post(data[:broker_id]))
    |> Map.merge(AssignedBrokerHelper.add_snooze_info(assigned_broker))
    |> Map.merge(AssignedBrokerHelper.add_lost_info(assigned_broker))
    # |> Map.merge(%{history: AssignedBrokerHelper.fetch_history(assigned_broker)})
    |> Map.merge(%{assigned_on_epoch: assigned_broker.inserted_at |> Time.naive_to_epoch()})
    |> Map.merge(%{history: [], last_active_at: nil, last_active_at_in_days: nil, last_post: true, last_post_days: nil, lost_reason: ""})
  end

  def is_snoozed?(assigned_broker) do
    case assigned_broker do
      nil ->
        false

      _ ->
        assigned_broker.snoozed and NaiveDateTime.compare(assigned_broker.snoozed_till, NaiveDateTime.utc_now()) == :gt
    end
  end

  def search_assigned_broker_query(employee_credential_id, search_text) do
    modified_search_text = "%" <> search_text <> "%"

    AssignedBrokers
    |> join(:inner, [ab], broker in Broker, on: broker.id == ab.broker_id)
    |> join(:inner, [ab, broker], cred in Credential, on: cred.broker_id == broker.id)
    |> join(:inner, [ab, broker, cred], org in Organization, on: org.id == cred.organization_id)
    |> join(:inner, [ab, broker, cred, org], polygon in Polygon, on: polygon.id == broker.polygon_id)
    |> where([ab, broker, cred], ab.employees_credentials_id == ^employee_credential_id and ab.active == true)
    |> where(
      [ab, broker, cred, org],
      ilike(broker.name, ^modified_search_text) or ilike(cred.phone_number, ^modified_search_text) or
        ilike(org.name, ^modified_search_text)
    )
    |> order_by([ab, broker, cred], fragment("lower(?) <-> ?", broker.name, ^search_text))
    |> select(
      [ab, broker, cred, org, polygon],
      %{
        id: broker.id,
        name: broker.name,
        phone_number: cred.phone_number,
        organization_id: org.id,
        organization_uuid: org.uuid,
        organization_name: org.name,
        organization_firm_address: org.firm_address,
        locality: polygon.name
      }
    )
  end

  def search_assigned_organization_query(employee_credential_id, search_text) do
    modified_search_text = "%" <> search_text <> "%"

    Organization
    |> join(:inner, [org], cred in Credential, on: cred.organization_id == org.id)
    |> join(:inner, [org, cred], b in Broker, on: b.id == cred.broker_id)
    |> join(:inner, [org, cred, b], ab in AssignedBrokers, on: ab.broker_id == b.id)
    |> where(
      [org, cred, b, ab],
      ab.active == true and cred.active == true and ab.employees_credentials_id == ^employee_credential_id
    )
    |> where([org, cred, b, ab], ilike(org.name, ^modified_search_text))
    |> order_by([org, cred, b, ab], fragment("lower(?) <-> ?", org.name, ^search_text))
    |> select(
      [org, cred, b, ab],
      %{
        id: org.id,
        uuid: org.uuid,
        name: org.name,
        firm_address: org.firm_address
      }
    )
  end

  def assigned_organization_data(broker_ids) do
    broker_ids
    |> assigned_broker_data()
    |> Enum.group_by(& &1[:org_uuid])
    |> Enum.map(fn {org_uuid, brokers_list} ->
      broker = brokers_list |> List.first()

      %{
        org_uuid: org_uuid,
        org_name: broker[:org_name],
        brokers_count: brokers_list |> length(),
        brokers_list: brokers_list,
        gst_number: broker[:gst_number],
        rera_id: broker[:rera_id],
        firm_address: broker[:firm_address],
        locality: broker[:polygon_id] && BnApis.Places.Polygon.fetch_from_id(broker[:polygon_id]).name
      }
    end)
  end

  def create_invited_user_assignment(invitor_id, broker_id) do
    cron_user_map = Utils.get_employee_user_map(%{"phone_number" => "cron", "country_code" => "+91"})

    invitor_credential = Credential.get_credential_by_id(invitor_id)

    case AssignedBrokers.fetch_assigned_broker(invitor_credential.broker_id) do
      nil ->
        nil

      assigned_broker ->
        AssignedBrokers.create_assignment(cron_user_map[:user_id], assigned_broker.employees_credentials_id, broker_id)
    end
  end

  def get_brokers_assigned_employee_number_for_hl(broker_id) do
    case fetch_one_broker(broker_id, "HOMELOAN") do
      nil ->
        nil

      broker ->
        broker = broker |> Repo.preload(:employees_credentials)
        broker.employees_credentials.phone_number
    end
  end

  def get_brokers_assigned_employee_id_for_hl(broker_id) do
    case fetch_one_broker(broker_id, "HOMELOAN") do
      nil ->
        nil

      broker ->
        broker = broker |> Repo.preload(:employees_credentials)
        broker.employees_credentials.id
    end
  end

  def fetch_channel_url(broker_id, employee_id) do
    AssignedBrokers
    |> where([ab], ab.active == true and ab.employees_credentials_id == ^employee_id and ab.broker_id == ^broker_id)
    |> select([ab], ab.channel_url)
    |> Repo.one()
  end
end
