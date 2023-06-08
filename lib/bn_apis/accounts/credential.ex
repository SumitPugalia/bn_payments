defmodule BnApis.Accounts.Credential do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query

  alias BnApis.BookingRewards.Schema.BookingRewardsLead
  alias BnApis.Developers.SiteVisit
  alias BnApis.Repo
  alias BnApis.{Accounts, Posts}
  alias BnApis.Accounts.{Credential, ProfileType}
  alias BnApis.Organizations.{Broker, BrokerRole, Organization, BillingCompany, OrgJoiningRequests}
  alias BnApis.Helpers.{FormHelper, S3Helper, AuditedRepo, Utils}
  alias BnApis.Accounts.Schema.PayoutMapping
  alias BnApis.Places.Polygon
  alias BnApis.Orders.MatchPlus
  alias BnApis.Accounts.Invite
  alias BnApis.Accounts.EmployeeCredential

  @brokers_per_page 10
  @time_delay 3

  schema "credentials" do
    field(:uuid, Ecto.UUID, read_after_writes: true)
    field(:phone_number, :string)
    field :country_code, :string, default: "+91"
    field(:fcm_id, :string)
    field(:chat_auth_token, :string)
    field(:last_active_at, :naive_datetime)
    field(:joining_date, :naive_datetime)
    field(:active, :boolean, default: false)
    field(:installed, :boolean, default: true)
    field(:auto_created, :boolean, default: false)
    field(:test_user, :boolean, default: false)
    field(:app_version, :string)
    field(:device_manufacturer, :string)
    field(:device_model, :string)
    field(:device_os_version, :string)
    field(:panel_auto_created, :boolean, default: false)
    field(:razorpay_contact_id, :string)
    field(:razorpay_fund_account_id, :string)
    field(:apns_id, :string)
    field(:source, :string)
    field(:notification_platform, :string)
    field(:sendbird_user_id, :string)
    field(:upi_id, :string)
    field(:upi_name, :string)

    belongs_to(:profile_type, ProfileType)
    belongs_to(:broker, Broker)

    belongs_to(:organization, Organization)
    belongs_to(:broker_role, BrokerRole)

    has_many(:payout_mapping, PayoutMapping,
      foreign_key: :cilent_uuid,
      references: :uuid
    )

    timestamps()
  end

  @fields [
    :phone_number,
    :country_code,
    :broker_id,
    :profile_type_id,
    :fcm_id,
    :chat_auth_token,
    :organization_id,
    :broker_role_id,
    :last_active_at,
    :active,
    :auto_created,
    :test_user,
    :installed,
    :panel_auto_created,
    :razorpay_contact_id,
    :razorpay_fund_account_id,
    :apns_id,
    :source,
    :device_manufacturer,
    :device_model,
    :device_os_version,
    :joining_date,
    :notification_platform,
    :sendbird_user_id,
    :upi_id,
    :upi_name
  ]
  @required_fields [:phone_number, :profile_type_id, :country_code]

  @doc false
  def changeset(credential, attrs \\ %{}) do
    credential
    |> cast(attrs, @fields)
    |> validate_required(@required_fields)
    |> foreign_key_constraint(:profile_type_id)
    |> foreign_key_constraint(:broker_id)
    |> foreign_key_constraint(:organization_id)
    |> foreign_key_constraint(:broker_role_id)
    |> validate_active_match_on_deactivation()
    |> restrict_upi_change()
    |> FormHelper.validate_phone_number(:phone_number)
  end

  # |> unique_constraint(:upi_id, name: :unique_upi_on_credentials, message: "UPI already in use.")

  @doc """
  1. Create a new record with the given params if it does not exist
  2. Get in case record exists
  """
  def create_or_get_credential(params = %{"phone_number" => phone_number, "country_code" => country_code}, user_map) do
    params =
      params
      |> Map.merge(%{
        "profile_type_id" => ProfileType.broker().id,
        "broker_role_id" => params["broker_role_id"] || BrokerRole.admin().id,
        "active" => true
      })

    case fetch_credential(phone_number, country_code) do
      nil ->
        # Accounts.remove_user_dnd(params["phone_number"])
        {:ok, credential} =
          %Credential{}
          |> Credential.changeset(params)
          |> AuditedRepo.insert(user_map)

        Exq.enqueue_in(Exq, "sendbird", @time_delay, BnApis.RegisterUserOnSendbird, [
          Credential.get_sendbird_payload(credential),
          credential.uuid
        ])

        {:ok, credential}

      credential ->
        {:ok, credential}
    end
  end

  def activate_credential(_params = %{"uuid" => uuid}, user_map) do
    case Repo.get_by(Credential, uuid: uuid) do
      nil ->
        {:error, "Credential not found"}

      credential ->
        case fetch_credential(credential.phone_number, credential.country_code) do
          nil ->
            credential |> Credential.activate_changeset() |> AuditedRepo.update(user_map)

            Exq.enqueue_in(Exq, "sendbird", @time_delay, BnApis.RegisterUserOnSendbird, [
              Credential.get_sendbird_payload(credential),
              uuid
            ])

            {:ok, credential}

          _active_credential ->
            {:error, "Broker with this number already active"}
        end
    end
  end

  @doc """
  1. Fetches active credential from phone number
  """
  def fetch_credential(phone_number, country_code, preload \\ []) do
    Credential
    |> where([c], c.phone_number == ^phone_number and c.country_code == ^country_code and c.active == true)
    |> Repo.one()
    |> Repo.preload(preload)
  end

  def fcm_changeset(credential, fcm_id, platform) do
    credential
    |> change(fcm_id: fcm_id)
    |> change(notification_platform: platform)
  end

  def apns_changeset(credential, apns_id) do
    credential
    |> change(apns_id: apns_id)
  end

  def app_type_changeset(credential, app_type) do
    credential
    |> change(source: app_type)
  end

  def broker_role_changeset(credential, broker_role_id) do
    credential
    |> change(broker_role_id: broker_role_id)
  end

  def promote_changeset(credential) do
    credential
    |> change(broker_role_id: BrokerRole.admin().id)
  end

  def demote_changeset(credential) do
    credential
    |> change(broker_role_id: BrokerRole.chhotus().id)
  end

  def activate_changeset(credential) do
    credential
    |> change(active: true)
    |> validate_active_match_on_deactivation()
  end

  def deactivate_changeset(credential) do
    credential
    |> change(active: false)
    |> validate_active_match_on_deactivation()
  end

  def test_user_changeset(credential) do
    credential
    |> change(test_user: true)
  end

  def update_last_active_at_query(id) do
    __MODULE__
    |> where(id: ^id)
    |> Ecto.Query.update(
      set: [
        last_active_at: fragment("date_trunc('second',now() AT TIME ZONE 'UTC')")
      ]
    )
  end

  def update_app_version(id, app_version, device_info) do
    __MODULE__
    |> where(id: ^id)
    |> Ecto.Query.update(
      set: [
        app_version: ^app_version,
        device_manufacturer: ^device_info["manufacturer"],
        device_model: ^device_info["model"],
        device_os_version: ^device_info["os-version"]
      ]
    )
  end

  def razorpay_changeset(
        credential,
        upi_id,
        upi_name,
        razorpay_contact_id,
        razorpay_fund_account_id
      ) do
    credential
    |> change(upi_id: upi_id)
    |> change(upi_name: upi_name)
    |> change(razorpay_contact_id: razorpay_contact_id)
    |> change(razorpay_fund_account_id: razorpay_fund_account_id)
  end

  def chat_auth_token_changeset(credential, chat_auth_token) do
    credential
    |> change(chat_auth_token: chat_auth_token)
  end

  def remove_user_tokens_changeset(credential) do
    credential
    |> change(chat_auth_token: nil)
    |> change(fcm_id: nil)
  end

  def remove_user_changeset(credential) do
    credential
    |> change(active: false)
  end

  def update_installed_flag(credential, installed \\ false) do
    credential
    |> change(fcm_id: nil)
    |> change(installed: installed)
  end

  def update_auto_created_flag(credential, user_map) do
    credential
    |> change(auto_created: false)
    |> AuditedRepo.update(user_map)
  end

  def update_broker_id(credential, broker_id, user_map) do
    credential
    |> change(broker_id: broker_id)
    |> AuditedRepo.update(user_map)
  end

  def update_organization_id(credential, organization_id, user_map) do
    credential
    |> change(organization_id: organization_id)
    |> AuditedRepo.update(user_map)
  end

  # def credential_broker_query(credential_uuid) do
  #   profile_type_id = ProfileType.broker.id

  #   user_query = Credential
  #   |> where(profile_type_id: ^profile_type_id)
  #   |> where(uuid: ^credential_uuid)
  #   |> join(:inner, [c], e in assoc(c, :broker))
  #   |> select([credential, broker],
  #     %{
  #       id: credential.id,
  #       broker_id: broker.id,
  #       organization_id: broker.organization_id,
  #       broker_role_id: broker.broker_role_id,
  #       active: broker.active,
  #     }
  #   )
  # end

  def get_by_uuid_query(credential_uuid) do
    Credential
    |> where(uuid: ^credential_uuid)
    |> preload(broker: [polygon: [:locality]])
    |> preload([:broker_role, :organization])
  end

  def promote_user(logged_in_user, _params = %{"user_uuid" => credential_uuid}) do
    _organization_id = logged_in_user[:organization_id]
    user_map = Utils.get_user_map(logged_in_user)
    logged_user_id = logged_in_user[:user_id]

    case Accounts.get_credential_by_uuid(credential_uuid) do
      nil ->
        {:error, "User not found!"}

      %{active: false, organization_id: _organization_id} ->
        {:error, "Cannot change role, User is inactive!"}

      %{id: id} when id == logged_user_id ->
        {:error, "Sorry, cannot promote own account!"}

      %{active: true, organization_id: _organization_id} = credential ->
        if credential.broker_role_id != BrokerRole.admin().id do
          if logged_in_user[:broker_role_id] == BrokerRole.admin().id do
            case credential |> promote_changeset() |> AuditedRepo.update(user_map) do
              {:ok, _credential} ->
                {:ok, "User successfully promoted!"}

              {:error, changeset} ->
                {:error, changeset}
            end
          else
            {:error, "You are not authorized to change role of this user!"}
          end
        else
          {:error, "User is already an admin!"}
        end
    end
  end

  def demote_user(logged_in_user, _params = %{"user_uuid" => credential_uuid}) do
    user_map = Utils.get_user_map(logged_in_user)
    logged_user_id = logged_in_user[:user_id]

    case Accounts.get_credential_by_uuid(credential_uuid) do
      nil ->
        {:error, "User not found!"}

      %{active: false, organization_id: _organization_id} ->
        {:error, "Cannot change role, User is inactive!"}

      %{id: id} when id == logged_user_id ->
        {:error, "Sorry, cannot demote own account!"}

      %{active: true, organization_id: _organization_id} = credential ->
        if credential.broker_role_id == BrokerRole.admin().id do
          if logged_in_user[:broker_role_id] == BrokerRole.admin().id do
            case credential |> demote_changeset() |> AuditedRepo.update(user_map) do
              {:ok, _credential} ->
                {:ok, "User successfully demoted!"}

              {:error, changeset} ->
                {:error, changeset}
            end
          else
            {:error, "You are not authorized to change role of this user!"}
          end
        else
          broker_role = BrokerRole.get_by_id(credential.broker_role_id)
          broker_role_name = if broker_role, do: broker_role.name, else: ""
          {:error, "User is already at #{broker_role_name} role!"}
        end
    end
  end

  def remove_user(logged_in_user, credential_uuid, successor_uuid) do
    admin_uuid = logged_in_user[:uuid]
    admin_org_id = logged_in_user[:organization_id]
    user_map = Utils.get_user_map(logged_in_user)

    with {:admin, true} <- {:admin, logged_in_user[:broker_role_id] == BrokerRole.admin().id},
         {:ok, successor} <- get_valid_successor(successor_uuid, credential_uuid, admin_org_id),
         {:ok, team_member} <- get_valid_team_member(credential_uuid, admin_uuid, admin_org_id),
         {:ok, _} <- remove_user_and_transfer_post(team_member, successor.id, user_map) do
      migrate_user_data_to_successor(team_member, successor)
      {:ok, "User successfully removed!"}
    else
      {:admin, false} -> {:error, "You are not authorized to remove user!"}
      {:error, :self} -> {:error, "Sorry, cannot remove own account!"}
      error -> error
    end
  end

  def leave_user(logged_in_user, successor_uuid) do
    user_uuid = logged_in_user[:uuid]
    user_org_id = logged_in_user[:organization_id]
    user_map = Utils.get_user_map(logged_in_user)

    with {:ok, successor} <- get_valid_successor(successor_uuid, user_uuid, user_org_id),
         {:ok, team_member} <- get_valid_team_member(user_uuid, nil, user_org_id),
         {:ok, _} <- remove_user_and_transfer_post(team_member, successor.id, user_map) do
      invites =
        Invite.new_invites_query(team_member.phone_number, team_member.country_code)
        |> Invite.invite_select_query()
        |> Repo.aggregate(:count, :id)

      if invites > 0, do: Credential.changeset(team_member, %{active: false}) |> Repo.update()
      members = Organization.get_organization_credential_list(user_org_id)
      maybe_make_successor_admin(successor, members)
      migrate_user_data_to_successor(team_member, successor)

      message = "#{team_member.broker.name} has left your organization."
      {data, type} = OrgJoiningRequests.get_push_notification_text(message)
      Enum.each(members, &OrgJoiningRequests.trigger_push_notification(&1, %{"data" => data, "type" => type}))

      {:ok, "Left organization successfully!"}
    else
      {:admin, false} -> {:error, "You are not authorized to remove user!"}
      {:error, :self} -> {:error, "Sorry, cannot remove own account!"}
      error -> error
    end
  end

  def add_limit(query, page \\ 1) do
    per_page = @brokers_per_page

    query
    |> limit(^per_page)
    |> offset(^((page - 1) * per_page))
  end

  def get_count(query) do
    query
    |> BnApis.Repo.aggregate(:count, :id)
  end

  def select_query(query, filter_broker_ids \\ []) do
    # if not empty then select those broker ids only
    filter_broker = filter_broker_ids |> length > 0

    query
    |> join(:inner, [cred], b in Broker, on: b.id == cred.broker_id)
    |> join(:left, [cred, b], o in Organization, on: o.id == cred.organization_id)
    |> where([c, b, o], not (^filter_broker) or b.id in ^filter_broker_ids)
    |> select([c, b, o], %{
      uuid: c.uuid,
      id: c.id,
      profile_image: b.profile_image,
      phone_number: c.phone_number,
      org_name: o.name,
      org_id: o.id,
      org_uuid: o.uuid,
      gst_number: o.gst_number,
      rera_id: o.rera_id,
      name: b.name,
      installed: c.installed,
      last_active_at: c.last_active_at,
      fcm_id: c.fcm_id,
      broker_id: b.id,
      polygon_id: b.polygon_id,
      broker_type_id: b.broker_type_id,
      firm_address: o.firm_address
    })
  end

  def credentials_query(page) do
    Credential |> where(active: true) |> add_limit(page) |> select_query
  end

  def get_credentials_in_polygons(uuids \\ [], filter_dsa? \\ false)

  def get_credentials_in_polygons(uuids, filter_dsa?) do
    Credential
    |> join(:inner, [c], b in Broker, on: b.id == c.broker_id)
    |> join(:inner, [c, b], p in Polygon, on: p.id == b.polygon_id)
    |> where([c, b, p], c.active == true and p.uuid in ^uuids)
    |> filter_by_broker_role_type(filter_dsa?)
    |> select([c, b, p], %{
      uuid: c.uuid,
      id: c.id,
      phone_number: c.phone_number,
      name: b.name,
      installed: c.installed,
      last_active_at: c.last_active_at,
      fcm_id: c.fcm_id,
      broker_id: b.id,
      polygon_name: p.name,
      polygon_id: p.id,
      polygon_uuid: p.uuid,
      broker_type_id: b.broker_type_id,
      notification_platform: c.notification_platform
    })
    |> Repo.all()
  end

  def employee_dashboard_credentials_query(page, broker_ids) do
    Credential
    |> where(active: true)
    |> order_by(asc: :last_active_at, asc: :installed)
    |> add_limit(page)
    |> select_query(broker_ids)
  end

  def user_credentials_query(user_id) do
    Credential |> where(active: true) |> where(id: ^user_id) |> select_query
  end

  @doc """
   1. Get all credentials based on the organization_id
   2. By default returns all active credentials
  """
  def get_credentials(organization_id, active \\ true)
  def get_credentials(organization_id, _) when is_nil(organization_id), do: []

  def get_credentials(organization_id, active) do
    Credential
    |> where([c], c.organization_id == ^organization_id and c.active == ^active)
    |> Repo.all()
  end

  @doc """
   1. Given the fcm_id fetches the credential
  """
  def get_credential_from_fcm(fcm_id) do
    Repo.get_by(Credential, fcm_id: fcm_id)
  end

  def get_active_broker_credentials() do
    Credential
    |> where(active: true)
    |> where([c], not is_nil(c.fcm_id))
    |> Repo.all()
  end

  def get_active_broker_credentials_above_version(app_version, operating_cities, type_dsa?) do
    Credential
    |> join(:inner, [c], b in Broker, on: b.id == c.broker_id)
    |> where([c, b], c.active == true)
    |> where([c, b], c.app_version > ^app_version)
    |> where(
      [c, b],
      not is_nil(c.fcm_id) and b.operating_city in ^operating_cities
    )
    |> Credential.filter_by_broker_role_type(type_dsa?)
    |> Repo.all()
  end

  def get_credentials_from_uuid(uuids) do
    Credential
    |> where([c], c.uuid in ^uuids)
    |> where([c], not is_nil(c.fcm_id))
    |> Repo.all()
  end

  def get_credential_by_id(id) do
    Credential
    |> Repo.get(id)
  end

  def get_broker_id_from_uuid(uuid) do
    Credential
    |> where([c], c.uuid == ^uuid and c.active == true)
    |> select([c], c.broker_id)
    |> Repo.one()
  end

  def get_credential_from_broker_id(broker_id, preloads \\ []) do
    Credential
    |> where([c], c.broker_id == ^broker_id and c.active == true)
    |> preload(^preloads)
    |> order_by([c], desc: c.updated_at)
    |> Repo.all()
    |> List.last()
  end

  def get_credential_from_broker_ids(broker_ids) when is_list(broker_ids) do
    Credential
    |> where([c], c.broker_id in ^broker_ids)
    |> order_by([c], desc: c.updated_at)
    |> Repo.all()
  end

  def get_any_credential_from_broker_id(broker_id) do
    Credential
    |> where([c], c.broker_id == ^broker_id)
    |> order_by([c], desc: c.updated_at)
    |> Repo.all()
    |> List.last()
  end

  @spec fetch_payout_metadata(Ecto.UUID.t()) :: nil | map()
  def fetch_payout_metadata(credential_uuid) do
    query =
      from(p in PayoutMapping,
        join: c in Credential,
        on: c.uuid == p.cilent_uuid,
        join: b in assoc(c, :broker),
        join: g in assoc(p, :payment_gateway),
        on: p.active == g.active,
        where: b.operating_city in g.city_ids and p.active == true and c.uuid == ^credential_uuid,
        select: %{contact_id: p.contact_id, fund_account_id: p.fund_account_id, name: g.name}
      )

    # There should not be more than one active payout method
    Repo.one(query)
  end

  def get_sendbird_payload(credential, is_update \\ false) do
    credential = credential |> Repo.preload([:broker])

    payload = %{
      "nickname" => credential.broker.name,
      "profile_url" =>
        if(not is_nil(credential.broker.profile_image),
          do: S3Helper.get_imgix_url(credential.broker.profile_image["url"]),
          else: S3Helper.get_imgix_url("profile_avatar.png")
        )
    }

    if is_update == false do
      payload
      |> Map.merge(%{
        "user_id" => credential.uuid,
        "metadata" => %{
          "phone_number" => credential.phone_number
        }
      })
    else
      payload
    end
  end

  def filter_by_broker_role_type(query, _filter_dsa? = true), do: where(query, [c, b], b.role_type_id == ^Broker.dsa()["id"])
  def filter_by_broker_role_type(query, _filter_dsa?), do: where(query, [c, b], b.role_type_id == ^Broker.real_estate_broker()["id"])

  def update_broker_organization(joining_request, broker_role_id, user_map) do
    requestor_cred = Credential |> Repo.get_by(id: joining_request.requestor_cred_id)

    requestor_cred
    |> changeset(%{
      organization_id: joining_request.organization_id,
      broker_role_id: broker_role_id
    })
    |> AuditedRepo.update(user_map)
  end

  defp migrate_user_data_to_successor(team_member, successor) do
    from_broker_id = team_member.broker.id
    to_broker_id = successor.broker.id

    SiteVisit.migrate_credential(team_member.id, successor.id)


    [BookingRewardsLead, BnApis.Stories.Schema.Invoice, BnApis.Homeloan.Lead, BnApis.Cabs.BookingRequest, BillingCompany, BnApis.Rewards.RewardsLead]
    |> Enum.each(fn atom ->
      from(l in atom, where: l.broker_id == ^from_broker_id, update: [set: [broker_id: ^to_broker_id]])
      |> Repo.update_all([])
    end)
  end

  defp maybe_make_successor_admin(successor, members) do
    if length(members) == 1 and successor.broker_role_id == BrokerRole.chhotus().id do
      successor
      |> Credential.changeset(%{broker_role_id: BrokerRole.admin().id})
      |> Repo.update()
    end
  end

  defp remove_user_and_transfer_post(credential, successor_cred_id, user_map) do
    {:ok, %Organization{} = organization} = %{"organization_name" => credential.broker.name} |> Organization.create_organization()

    case credential |> Credential.update_organization_id(organization.id, user_map) do
      {:ok, credential} ->
        Posts.assign_all_posts_to_me(credential.id, successor_cred_id)
        BillingCompany.deactivate_brokers_billing_companies(credential.broker_id)

        kyc_changes = %{
          kyc_status: :missing,
          is_rera_verified: false,
          is_pan_verified: false,
          rera: nil,
          rera_name: nil,
          rera_file: nil
        }

        Broker.update_kyc_status(credential.broker, kyc_changes, user_map)

        joining_request_id = OrgJoiningRequests.fetch_org_joining_request_by_requestor_cred_id(credential.id)
        if not is_nil(joining_request_id), do: OrgJoiningRequests.cancel_org_joining_request(joining_request_id, credential.id)

        {:ok, "User successfully removed!"}

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  defp get_valid_team_member(credential_uuid, admin_uuid, admin_org_id) do
    case Accounts.get_credential_by_uuid(credential_uuid) do
      nil -> {:error, "Invalid team member"}
      %{uuid: uuid} when uuid == admin_uuid -> {:error, :self}
      %{active: active, organization_id: org_id} when active == false or org_id != admin_org_id -> {:error, "Invalid team member"}
      credential -> {:ok, Repo.preload(credential, [:broker])}
    end
  end

  defp get_valid_successor(successor_uuid, credential_uuid, admin_org_id) do
    case Accounts.get_credential_by_uuid(successor_uuid) do
      nil -> {:error, "Invalid Successor"}
      %{uuid: uuid} when uuid == credential_uuid -> {:error, "User to be removed cannot be a successor"}
      %{active: false, organization_id: _organization_id} -> {:error, "Invalid Successor"}
      %{active: true, organization_id: org_id} when org_id != admin_org_id -> {:error, "Successor should belong to your own organization"}
      credential -> {:ok, Repo.preload(credential, [:broker])}
    end
  end

  defp restrict_upi_change(changeset = %{valid?: true}) do
    upi_id_changed? = not is_nil(Map.get(changeset.changes, :upi_id))
    upi_name = Map.get(changeset.changes, :upi_name) || get_field(changeset, :upi_name)
    broker_id = Map.get(changeset.changes, :broker_id) || get_field(changeset, :broker_id)

    broker_name = if not is_nil(broker_id), do: Repo.get(Broker, broker_id).name, else: nil

    if upi_id_changed? and ((not is_nil(upi_name) and not is_nil(broker_name) and String.downcase(broker_name) != String.downcase(upi_name)) or is_nil(upi_name)) do
      add_error(changeset, :pan, "UPI name does not match profile name")
    else
      changeset
    end
  end

  defp restrict_upi_change(changeset), do: changeset

  defp validate_active_match_on_deactivation(changeset) do
    case changeset.valid? do
      true ->
        is_getting_deactivated = get_field(changeset, :active) == false
        is_currently_active = changeset.data.active == true

        if is_getting_deactivated and is_currently_active do
          active_match_plus =
            MatchPlus
            |> where(
              [mp],
              mp.broker_id == ^changeset.data.broker_id and mp.status_id == ^1
            )
            |> Repo.all()
            |> length

          is_match_plus_active = active_match_plus > 0

          if is_match_plus_active do
            add_error(
              changeset,
              :status_id,
              "Broker has active match plus and hence cannot be deactivated"
            )
          else
            changeset
          end
        else
          changeset
        end

      _ ->
        changeset
    end
  end

  # dsa employees can also be logged in as a dsa
  def get_employee_id_using_broker_id(broker_id) do
    credential = get_credential_from_broker_id(broker_id)

    EmployeeCredential
    |> where([ec], ec.phone_number == ^credential.phone_number and ec.active == true)
    |> select([ec], ec.id)
    |> Repo.one()
  end

  def get_employee_details_using_broker_id(broker_id) do
    credential = get_credential_from_broker_id(broker_id)

    EmployeeCredential
    |> where([ec], ec.phone_number == ^credential.phone_number and ec.active == true)
    |> select([ec], %{"name" => ec.name, "phone_number" => ec.phone_number, "user_id" => ec.uuid})
    |> Repo.one()
  end
end
