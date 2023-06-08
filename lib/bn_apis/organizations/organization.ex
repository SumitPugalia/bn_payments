defmodule BnApis.Organizations.Organization do
  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query

  alias BnApis.Repo

  alias BnApis.{Accounts, AssignedBrokers}
  alias BnApis.Accounts.{Credential, Invite, InviteStatus, ProfileType}
  alias BnApis.Organizations.{Broker, BrokerRole, Organization}
  alias BnApis.Helpers.{ApplicationHelper, AssignedBrokerHelper, AuditedRepo}
  alias BnApis.Accounts.EmployeeCredential
  alias BnApis.Places.City
  alias BnApis.Places.Polygon
  alias BnApisWeb.Helpers.PhoneHelper, as: Phone

  schema "organizations" do
    field(:uuid, Ecto.UUID, read_after_writes: true)
    field(:gst_number, :string)
    field(:name, :string)
    field(:rera_id, :string)
    field(:firm_address, :string)
    field(:place_id, :string)
    field :real_estate_id, :integer
    field :team_upi_cred_uuid, Ecto.UUID
    field :members_can_add_billing_company, :boolean

    timestamps()
  end

  @fields [:uuid, :name, :gst_number, :rera_id, :firm_address, :place_id, :real_estate_id, :team_upi_cred_uuid, :members_can_add_billing_company]
  @required_fields [:name]

  # TODO: Add regex validation for gstin and rera_id

  @doc false
  def changeset(organization, attrs \\ %{}) do
    organization
    |> cast(attrs, @fields)
    |> validate_required(@required_fields)
    |> unique_constraint(:name, name: :organizations_name_rera_gst_id_index)
    |> unique_constraint(:gst_number)
    |> unique_constraint(:rera_id)
    |> unique_constraint(:real_estate_id)
  end

  def get_organization(id) do
    Repo.get(Organization, id)
  end

  def get_organization_by_uuid(id) do
    Repo.get_by(Organization, uuid: id)
  end

  def get_organization_from_cred(cred_id) do
    Credential
    |> join(:inner, [cred], o in assoc(cred, :organization))
    |> where([cred], cred.id == ^cred_id and cred.active == true)
    |> select([cred, o], o)
    |> Repo.one()
  end

  def create_organization(params) do
    changeset = %{
      name: params["organization_name"],
      firm_address: params["firm_address"],
      place_id: params["place_id"],
      real_estate_id: params["real_estate_id"],
      gst_number: params["gst_number"]
    }

    %Organization{}
    |> Organization.changeset(changeset)
    |> Repo.insert()
  end

  @doc """
  1. Create a new record with the given params if it does not exist
  2. Get in case record exists
  """
  def create_or_get_organization(organization_name) do
    case fetch_organization(organization_name) do
      nil ->
        %Organization{}
        |> Organization.changeset(%{name: organization_name})
        |> Repo.insert()

      organization ->
        {:ok, organization}
    end
  end

  @doc """
  1. Fetches active organaization from name
  """
  def fetch_organization(name) do
    Organization
    |> where([o], o.name == ^name)
    |> Repo.all()
    |> List.last()
  end

  def signup_user_changeset(
        params = %{
          "name" => name,
          "phone_number" => phone_number,
          "country_code" => country_code
          # "fcm_id" => fcm_id,
          # "profile_image" => profile_image # Not Mandatory
        },
        user_map
      ) do
    fn ->
      attrs = %{
        phone_number: phone_number,
        country_code: country_code,
        profile_type_id: ProfileType.broker().id
      }

      {:ok, credential} = Accounts.create_credential(attrs, user_map)

      {:ok, profile_image} = Broker.upload_image_to_s3(params["profile_image"], credential.uuid)

      broker_attrs = %{
        "profile_image" => profile_image,
        "name" => name,
        "operating_city" => params["operating_city"]
      }

      broker_changeset = Broker.changeset(%Broker{}, broker_attrs)

      broker =
        case AuditedRepo.insert(broker_changeset, user_map) do
          {:ok, broker} ->
            broker

          {:error, changeset} ->
            Repo.rollback(changeset)
        end

      # Organization is OPTIONAL
      org_name = params["organization_name"]

      organization =
        if org_name do
          organization_changeset =
            Organization.changeset(%Organization{}, %{
              name: org_name,
              firm_address: params["firm_address"],
              place_id: params["place_id"]
            })

          case Repo.insert(organization_changeset) do
            {:ok, organization} ->
              organization

            {:error, changeset} ->
              Repo.rollback(changeset)
          end
        end

      credential_attrs = %{
        fcm_id: params["fcm_id"],
        broker_id: broker.id,
        active: true,
        organization_id: (Map.has_key?(organization || %{}, :id) && organization.id) || nil,
        broker_role_id: BrokerRole.admin().id,
        chat_auth_token: SecureRandom.urlsafe_base64(64),
        panel_auto_created: false
      }

      credential_changeset = Credential.changeset(credential, credential_attrs)

      credential =
        case AuditedRepo.update(credential_changeset, user_map) do
          {:ok, credential} ->
            credential

          {:error, changeset} ->
            Repo.rollback(changeset)
        end

      qr_code_url = Broker.upload_qr_code(credential)
      Broker.changeset(broker, %{"qr_code_url" => qr_code_url}) |> AuditedRepo.update(user_map)

      {credential}
    end
  end

  def whatsapp_signup_user_changeset(
        params = %{
          "name" => name,
          "phone_number" => _phone_number
        },
        credential,
        user_map
      ) do
    fn ->
      {:ok, profile_image} = Broker.upload_image_to_s3(params["profile_image"], credential.uuid)

      broker = Repo.get(Broker, credential.broker_id) || %Broker{}

      broker_attrs = %{
        "profile_image" => profile_image,
        "name" => name,
        "operating_city" => broker.operating_city || params["operating_city"]
      }

      broker_changeset = Broker.changeset(broker, broker_attrs)

      broker =
        case AuditedRepo.insert_or_update(broker_changeset, user_map) do
          {:ok, broker} ->
            broker

          {:error, changeset} ->
            Repo.rollback(changeset)
        end

      # Organization is OPTIONAL
      org_name = params["organization_name"]

      organization = Repo.get(Organization, credential.organization_id) || %Organization{}

      organization =
        if org_name do
          organization_changeset =
            Organization.changeset(organization, %{
              name: org_name,
              firm_address: params["firm_address"] || organization.firm_address,
              place_id: params["place_id"] || organization.place_id
            })

          case Repo.insert_or_update(organization_changeset) do
            {:ok, organization} ->
              organization

            {:error, changeset} ->
              Repo.rollback(changeset)
          end
        end

      credential_attrs = %{
        fcm_id: params["fcm_id"],
        broker_id: broker.id,
        active: true,
        installed: true,
        organization_id: (Map.has_key?(organization || %{}, :id) && organization.id) || nil,
        broker_role_id: credential.broker_role_id || BrokerRole.admin().id,
        chat_auth_token: SecureRandom.urlsafe_base64(64),
        auto_created: false,
        panel_auto_created: false
      }

      credential_changeset = Credential.changeset(credential, credential_attrs)

      credential =
        case AuditedRepo.update(credential_changeset, user_map) do
          {:ok, credential} ->
            credential

          {:error, changeset} ->
            Repo.rollback(changeset)
        end

      qr_code_url = Broker.upload_qr_code(credential)
      Broker.changeset(broker, %{"qr_code_url" => qr_code_url}) |> AuditedRepo.update(user_map)

      {credential}
    end
  end

  def signup_invited_user_changeset(
        params = %{
          "name" => name,
          "organization_id" => org_id,
          "phone_number" => phone_number,
          "country_code" => country_code
          # "profile_image" => profile_image, #OPTIONAL
          # "fcm_id" => fcm_id, #OPTIONAL
        },
        invite,
        user_map
      ) do
    fn ->
      attrs = %{
        phone_number: phone_number,
        country_code: country_code,
        profile_type_id: ProfileType.broker().id
      }

      {:ok, credential} =
        case Credential.fetch_credential(phone_number, country_code) do
          nil -> Accounts.create_credential(attrs, user_map)
          cred -> {:ok, cred}
        end

      {:ok, profile_image} = Broker.upload_image_to_s3(params["profile_image"], credential.uuid)

      {operating_city, polygon_id} =
        case Organization.fetch_poly_data_from_org(org_id) do
          %{operating_city: operating_city, polygon_id: polygon_id} ->
            {operating_city, polygon_id}

          _ ->
            {nil, nil}
        end

      broker_attrs = %{
        "profile_image" => profile_image,
        "name" => name,
        "operating_city" => params["operating_city"] || operating_city,
        "polygon_id" => polygon_id
      }

      {result, broker} =
        if not is_nil(credential.broker_id) do
          Repo.get(Broker, credential.broker_id)
          |> Broker.changeset(broker_attrs)
          |> AuditedRepo.update(user_map)
        else
          %Broker{}
          |> Broker.changeset(broker_attrs)
          |> AuditedRepo.insert(user_map)
        end

      if result == :error, do: Repo.rollback(broker)

      credential_attrs = %{
        fcm_id: params["fcm_id"],
        broker_id: broker.id,
        active: true,
        organization_id: org_id,
        broker_role_id: invite.broker_role_id,
        chat_auth_token: SecureRandom.urlsafe_base64(64),
        panel_auto_created: false
      }

      credential_changeset = Credential.changeset(credential, credential_attrs)

      credential =
        case AuditedRepo.update(credential_changeset, user_map) do
          {:ok, credential} ->
            credential

          {:error, changeset} ->
            Repo.rollback(changeset)
        end

      qr_code_url = Broker.upload_qr_code(credential)
      Broker.changeset(broker, %{"qr_code_url" => qr_code_url}) |> AuditedRepo.update(user_map)

      # Change Invite to Accepted
      invite
      |> Invite.mark_invite_as_changeset(InviteStatus.accepted().id)
      |> Repo.update!()

      # Cancel rest of the invites
      Invite.cancel_other_invites(phone_number, country_code)

      AssignedBrokers.create_invited_user_assignment(invite.invited_by_id, credential.broker_id)

      {credential}
    end
  end

  def auto_assign_broker(org_id, broker_id) do
    broker_ids = get_organization_brokers_from_id(org_id) |> Enum.map(& &1[:broker_id])

    assigned_brokers = AssignedBrokers.fetch_assigned_brokers(broker_ids)
    assigned_broker = List.first(assigned_brokers)

    unless is_nil(assigned_broker) do
      # assign this broker to an employee who has this org assigned
      AssignedBrokerHelper.create_employee_assignments(
        nil,
        assigned_broker.employees_credentials_id,
        [broker_id]
      )
    end
  end

  def toggle_billing_company_preference(cred_id, role_id, action, user_map) do
    with {:valid, true} <- {:valid, BrokerRole.admin().id == role_id},
         %Organization{members_can_add_billing_company: access} = org when access == not action <- get_organization_from_cred(cred_id) do
      msg = if action, do: "Now only admins can create new billing companies", else: "Now everyone can create new billing companies"
      send_push_notification_to_team(cred_id, org, msg)

      org
      |> changeset(%{members_can_add_billing_company: action})
      |> AuditedRepo.update(user_map)
    else
      %Organization{} = org -> {:ok, org}
      {:valid, false} -> {:error, "Only admin can edit this flag"}
      nil -> {:error, :not_found}
    end
  end

  def toggle_team_upi(cred_id, role_id, user_map, true) do
    with {:valid, true} <- {:valid, BrokerRole.admin().id == role_id},
         %Organization{} = org <- get_organization_from_cred(cred_id),
         %Credential{upi_id: upi_id, razorpay_contact_id: contact_id, razorpay_fund_account_id: fund_id, uuid: uuid}
         when nil not in [upi_id, contact_id, fund_id] <-
           Repo.get_by(Credential, id: cred_id) do
      msg = "Now your site visit rewards will be paid to #{upi_id}"
      send_push_notification_to_team(cred_id, org, msg)
      changeset(org, %{team_upi_cred_uuid: uuid}) |> AuditedRepo.update(user_map)
    else
      {:valid, false} -> {:error, "Only admin can edit this flag"}
      nil -> {:error, :not_found}
      %Credential{} -> {:error, :incomplete_upi}
    end
  end

  def toggle_team_upi(cred_id, role_id, user_map, false) do
    with {:valid, true} <- {:valid, BrokerRole.admin().id == role_id},
         %Organization{} = org <- get_organization_from_cred(cred_id) do
      changeset(org, %{team_upi_cred_uuid: nil}) |> AuditedRepo.update(user_map)
    else
      {:valid, false} -> {:error, "Only admin can edit this flag"}
      nil -> {:error, :not_found}
    end
  end

  def get_org_settings(cred_id) do
    case get_organization_from_cred(cred_id) do
      %Organization{} = org ->
        cred = if is_nil(org.team_upi_cred_uuid), do: Repo.get_by(Credential, id: cred_id), else: Repo.get_by(Credential, uuid: org.team_upi_cred_uuid)

        %{
          members_can_add_billing_company: org.members_can_add_billing_company,
          payment_from_org_upi: not is_nil(org.team_upi_cred_uuid),
          upi: cred.upi_id
        }

      nil ->
        {:error, :not_found}
    end
  end

  defp allowed_roles_map(broker_role_id) do
    cond do
      broker_role_id == BrokerRole.admin().id ->
        [BrokerRole.admin().id]

      broker_role_id == BrokerRole.chhotus().id ->
        [BrokerRole.admin().id]
    end
  end

  defp invite_link() do
    ApplicationHelper.playstore_app_url()
  end

  def save_and_send_invite(invite_params = %{phone_number: phone_number, country_code: country_code}, message) do
    case Invite.changeset(invite_params) |> Repo.insert() do
      {:ok, invite} ->
        Exq.enqueue(Exq, "send_sms", BnApis.SendSmsWorker, [country_code <> phone_number, message])
        {:ok, invite.uuid, "Invitation sent!"}

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  def invite(
        logged_in_user,
        params = %{
          "phone_number" => _phone_number,
          "broker_role_id" => broker_role_id,
          "broker_name" => broker_name
        }
      ) do
    logged_organization_id = logged_in_user[:organization_id]
    logged_organization_name = logged_in_user[:organization_name]
    logged_user_id = logged_in_user[:user_id]

    subject_broker_role_id = broker_role_id |> String.to_integer()
    allowed_broker_role_ids = allowed_roles_map(subject_broker_role_id)

    broker_role_name = BrokerRole.get_by_id(subject_broker_role_id).name
    {:ok, phone_number, country_code} = Phone.parse_phone_number(params)

    if logged_in_user[:broker_role_id] == BrokerRole.admin().id ||
         allowed_broker_role_ids
         |> Enum.member?(logged_in_user[:broker_role_id]) do
      profile_type_id = ProfileType.broker().id

      invite_params = %{
        broker_name: broker_name,
        broker_role_id: subject_broker_role_id,
        phone_number: phone_number,
        country_code: country_code,
        invite_status_id: InviteStatus.new().id,
        invited_by_id: logged_user_id
      }

      user_query =
        Credential
        |> where(profile_type_id: ^profile_type_id)
        |> where(
          [c],
          c.phone_number == ^phone_number and
            c.organization_id == ^logged_organization_id
        )
        |> preload([:broker, :organization, :broker_role])

      case user_query |> Repo.one() do
        nil ->
          # Inviting to this new organization
          message = "Hi #{broker_name}, please click on this link to join \"#{logged_organization_name}\" as #{broker_role_name} - #{invite_link()}"

          save_and_send_invite(invite_params, message)

        %{active: true} = _credential ->
          {:error, "User already part of this organization and active. No need to send invite!"}

        %{active: false} = _credential ->
          # User was part of this organization and is now inactive!
          # Send Invite to activate this old account.
          user_query =
            Credential
            |> where(profile_type_id: ^profile_type_id)
            |> where(active: true)
            |> where(
              [c],
              c.phone_number == ^phone_number and
                c.organization_id != ^logged_organization_id
            )
            |> preload([:broker, :organization, :broker_role])

          case user_query |> Repo.one() do
            nil ->
              # User not active in any other organization
              message = "Hi #{broker_name}, please click on this link to join \"#{logged_organization_name}\" as #{broker_role_name} - #{invite_link()}"

              save_and_send_invite(invite_params, message)

            _user ->
              # User active in some other organization
              message = "Hi #{broker_name}, please click on this link to join \"#{logged_organization_name}\" as #{broker_role_name} - #{invite_link()}. \n
                  P.S - You need/ask to leave your current organization, before joining this."

              save_and_send_invite(invite_params, message)
          end
      end
    else
      broker_role = BrokerRole.get_by_id(subject_broker_role_id)

      broker_role_name_string =
        if broker_role do
          " as #{broker_role.name}"
        else
          ""
        end

      {:error, "you are not authorized to invite member#{broker_role_name_string} to this organization"}
    end
  end

  def resend_invite(
        logged_in_user,
        _params = %{
          "invite_uuid" => invite_uuid
        }
      ) do
    logged_organization_id = logged_in_user[:organization_id]
    logged_organization_name = logged_in_user[:organization_name]

    new_invite_status_id = InviteStatus.new().id

    case Repo.get_by!(Invite, uuid: invite_uuid) do
      nil ->
        {:error, "Invite not found!"}

      %{invite_status_id: status_id} = invite
      when status_id == new_invite_status_id ->
        invite_organization_id =
          case Accounts.get_credential!(invite.invited_by_id) do
            nil -> nil
            cred -> cred.organization_id
          end

        if logged_organization_id == invite_organization_id and
             logged_in_user[:broker_role_id] == BrokerRole.admin().id do
          broker_role_name = BrokerRole.get_by_id(invite.broker_role_id).name

          message = "Hi #{invite.broker_name}, please click on this link to join \"#{logged_organization_name}\" as #{broker_role_name} - #{invite_link()}"

          Exq.enqueue(Exq, "send_sms", BnApis.SendSmsWorker, [invite.country_code <> invite.phone_number, message])
          {:ok, invite.uuid, "User successfully re-invited to organization"}
        else
          broker_role = BrokerRole.get_by_id(invite.broker_role_id)

          broker_role_name_string =
            if broker_role do
              " as #{broker_role.name}"
            else
              ""
            end

          {:error, "you are not authorized to re-send invite to member#{broker_role_name_string} to this organization"}
        end

      _ ->
        {:error, "Invite either cancelled/accepted/expired. Cannot re-send invite!"}
    end
  end

  def cancel_invite(
        logged_in_user,
        _params = %{
          "invite_uuid" => invite_uuid
        }
      ) do
    logged_organization_id = logged_in_user[:organization_id]
    logged_organization_name = logged_in_user[:organization_name]

    cancelled_invite_status_id = InviteStatus.cancelled().id
    accepted_invite_status_id = InviteStatus.accepted().id
    expired_invite_status_id = InviteStatus.expired().id

    case Repo.get_by!(Invite, uuid: invite_uuid) do
      nil ->
        {:error, "Invite not found!"}

      %{invite_status_id: status_id} = _invite
      when status_id == cancelled_invite_status_id ->
        {:error, "Invite already cancelled!"}

      %{invite_status_id: status_id} = _invite
      when status_id == accepted_invite_status_id ->
        {:error, "Invite already Accepted.Cannot cancel invite!"}

      %{invite_status_id: status_id} = _invite
      when status_id == expired_invite_status_id ->
        {:error, "Invite already expired.Cannot cancel invite!"}

      invite ->
        invite_organization_id =
          case Accounts.get_credential!(invite.invited_by_id) do
            nil -> nil
            cred -> cred.organization_id
          end

        if logged_organization_id == invite_organization_id and
             logged_in_user[:broker_role_id] == BrokerRole.admin().id do
          cancel_changeset =
            invite
            |> Invite.changeset(%{invite_status_id: InviteStatus.cancelled().id})

          case cancel_changeset |> Repo.update() do
            {:ok, _updated_invite} ->
              broker_role_name = BrokerRole.get_by_id(invite.broker_role_id).name

              message = "Hi #{invite.broker_name}, your invitation to join \"#{logged_organization_name}\" as #{broker_role_name} has been cancelled!"

              Exq.enqueue(Exq, "send_sms", BnApis.SendSmsWorker, [invite.country_code <> invite.phone_number, message])
              {:ok, invite.uuid, "User invite cancelled successfully!"}

            {:error, changeset} ->
              {:error, changeset}
          end
        else
          broker_role = BrokerRole.get_by_id(invite.broker_role_id)

          broker_role_name_string =
            if broker_role do
              " as #{broker_role.name}"
            else
              ""
            end

          {:error, "you are not authorized to cancel member#{broker_role_name_string} to this organization"}
        end
    end
  end

  def active_team_members_query(organization_id) do
    Credential
    |> join(:left, [c], b in Broker, on: b.id == c.broker_id)
    |> where([c], c.organization_id == ^organization_id and c.active == true)
    |> select([c, b], %{user_id: c.uuid, name: b.name, phone_number: c.phone_number, profile_image: b.profile_image, broker_role_id: c.broker_role_id})
    |> order_by([c, b], asc: b.name)
  end

  def admin_members_query(organization_id) do
    admin_role_id = BrokerRole.admin().id

    active_team_members_query(organization_id)
    |> where(broker_role_id: ^admin_role_id)
  end

  def chhotus_members_query(organization_id) do
    chhotus_role_id = BrokerRole.chhotus().id

    active_team_members_query(organization_id)
    |> where(broker_role_id: ^chhotus_role_id)
  end

  def all_active_organizations() do
    Organization
    |> distinct(true)
    |> join(:inner, [o], c in Credential, on: c.organization_id == o.id)
    |> where([o, c], c.active == true)
    |> Repo.all()
  end

  def get_organization_brokers(organization_uuids, role_type_id \\ nil)

  def get_organization_brokers(organization_uuids, _role_type_id) when is_list(organization_uuids) do
    Organization
    |> join(:inner, [o], c in Credential, on: c.organization_id == o.id)
    |> join(:inner, [o, c], b in Broker, on: c.broker_id == b.id)
    |> join(:left, [o, c, b], eab in AssignedBrokers, on: eab.broker_id == b.id and eab.active == true)
    |> join(:left, [o, c, b, eab], ec in EmployeeCredential, on: ec.id == eab.employees_credentials_id)
    |> where([o, c, b, eab], c.active == true and o.uuid in ^organization_uuids)
    |> select([o, c, b, eab, ec], %{
      org_name: o.name,
      org_uuid: o.uuid,
      broker_id: b.id,
      broker_name: b.name,
      phone_number: c.phone_number,
      employee_mapping_active: eab.active,
      assigned_employee: %{
        name: ec.name,
        phone_number: ec.phone_number,
        vertical_id: ec.vertical_id
      }
    })
    |> Repo.all()
  end

  def get_organization_brokers(organization_uuid, role_type_id) do
    real_estate_broker_role_id = Broker.real_estate_broker()["id"]
    dsa_role_id = Broker.dsa()["id"]

    query =
      Organization
      |> join(:inner, [o], c in Credential, on: c.organization_id == o.id)
      |> join(:inner, [o, c], b in Broker, on: c.broker_id == b.id)
      |> join(:left, [o, c, b], eab in AssignedBrokers, on: eab.broker_id == b.id and eab.active == true)
      |> join(:left, [o, c, b, eab], ec in EmployeeCredential, on: ec.id == eab.employees_credentials_id)
      |> where([o, c, b, eab], c.active == true and o.uuid == ^organization_uuid)

    query =
      if role_type_id == dsa_role_id do
        query |> where([o, c, b, eab], b.role_type_id == ^dsa_role_id)
      else
        query |> where([o, c, b, eab], b.role_type_id == ^real_estate_broker_role_id)
      end

    query
    |> select([o, c, b, eab, ec], %{
      org_name: o.name,
      org_uuid: o.uuid,
      broker_id: b.id,
      broker_name: b.name,
      phone_number: c.phone_number,
      employee_mapping_active: eab.active,
      assigned_employee: %{
        name: ec.name,
        phone_number: ec.phone_number,
        vertical_id: ec.vertical_id
      }
    })
    |> Repo.all()
  end

  def get_organization_brokers_from_id(organization_id) do
    Organization
    |> join(:inner, [o], c in Credential, on: c.organization_id == o.id)
    |> join(:inner, [o, c], b in Broker, on: c.broker_id == b.id)
    |> where([o, c], c.active == true and o.id == ^organization_id)
    |> select([o, c, b], %{
      org_name: o.name,
      org_uuid: o.uuid,
      broker_id: b.id,
      broker_name: b.name,
      phone_number: c.phone_number
    })
    |> Repo.all()
  end

  def fetch_poly_data_from_org(org_id) do
    Organization
    |> join(:inner, [o], c in Credential, on: c.organization_id == o.id)
    |> join(:inner, [o, c], b in Broker, on: c.broker_id == b.id)
    |> where([o, c, b], c.active == true and o.id == ^org_id)
    |> where(
      [o, c, b],
      not is_nil(b.operating_city) and not is_nil(b.polygon_id)
    )
    |> limit(1)
    |> select([o, c, b], %{
      operating_city: b.operating_city,
      polygon_id: b.polygon_id
    })
    |> Repo.one()
  end

  def get_organization_broker(organization_uuid) do
    Organization
    |> join(:inner, [o], c in Credential, on: c.organization_id == o.id)
    |> join(:inner, [o, c], b in Broker, on: c.broker_id == b.id)
    |> where([o, c], c.active == true and o.uuid == ^organization_uuid)
    |> where([o, c, b], not is_nil(b.polygon_id))
    |> limit(1)
    |> select([o, c, b], %{
      broker_id: b.id,
      broker_name: b.name,
      polygon_id: b.polygon_id
    })
    |> Repo.one()
  end

  def get_organization_credential_list(organization_id) do
    Organization
    |> join(:inner, [o], c in Credential, on: c.organization_id == o.id)
    |> join(:inner, [o, c], b in Broker, on: c.broker_id == b.id)
    |> where([o, c], c.active == true and o.id == ^organization_id)
    |> select([o, c, b], c)
    |> Repo.all()
  end

  def filter_organizations("", _page, _limit), do: []

  def filter_organizations(query, page, limit) do
    offset = (page - 1) * limit

    cred_sub =
      Credential
      |> where([cred], cred.active == true and cred.broker_role_id == ^BrokerRole.admin()[:id])
      |> distinct([cred], cred.organization_id)
      |> order_by([cred], asc: cred.id)
      |> select([cred], %{
        organization_id: cred.organization_id,
        broker_id: cred.broker_id
      })

    Organization
    |> join(:inner, [o], cr in subquery(cred_sub), on: cr.organization_id == o.id)
    |> join(:inner, [o, cr], b in Broker, on: cr.broker_id == b.id)
    |> join(:inner, [o, cr, b], city in City, on: b.operating_city == city.id)
    |> join(:inner, [o, cr, b, city], p in Polygon, on: b.polygon_id == p.id)
    |> where([o, cr, b, city, p], ilike(o.name, ^("%" <> String.downcase(query) <> "%")))
    |> order_by([o, cr, b, city, p], asc: o.name)
    |> limit(^limit)
    |> offset(^offset)
    |> select([o, cr, b, city, p], %{
      uuid: o.uuid,
      name: o.name,
      firm_address: o.firm_address,
      city_id: city.id,
      city_name: city.name,
      polygon_uuid: p.uuid,
      polygon_name: p.name
    })
    |> Repo.all()
  end

  def find_or_create_organization(organization_name, organization_gst_number) do
    Organization
    |> where([o], ilike(o.gst_number, ^organization_gst_number))
    |> limit(1)
    |> Repo.one()
    |> case do
      nil ->
        Organization.create_organization(%{"organization_name" => organization_name, "gst_number" => organization_gst_number})

      org ->
        {:ok, org}
    end
  end

  def send_push_notification_to_team(cred_id, org, msg) do
    Exq.enqueue(Exq, "team_notification", BnApis.Brokers.OrgNotificationWorker, [cred_id, org.uuid, msg])
  end
end
