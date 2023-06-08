defmodule BnApis.Organizations do
  @moduledoc """
  The Brokers context.
  """

  import Ecto.Query, warn: false
  alias BnApis.Repo

  alias BnApis.Accounts
  alias BnApis.Accounts.Invite
  alias BnApis.Organizations.{Broker, BrokerRole, Organization, OrgJoiningRequests}
  alias BnApis.Helpers.{S3Helper, Utils, AuditedRepo}
  alias BnApis.Accounts.Credential
  alias BnApisWeb.Helpers.PhoneHelper, as: Phone

  @get_team_size 11

  @doc """
  Returns the list of organizations.

  ## Examples

      iex> list_organizations()
      [%Organization{}, ...]

  """
  def list_organizations do
    Repo.all(Organization)
  end

  @doc """
  Gets a single organization.

  Raises `Ecto.NoResultsError` if the Organization does not exist.

  ## Examples

      iex> get_organization!(123)
      %Organization{}

      iex> get_organization!(456)
      ** (Ecto.NoResultsError)

  """
  def get_organization!(id), do: Repo.get!(Organization, id)
  def get_organization_by_uuid(uuid), do: Repo.get_by(Organization, uuid: uuid)

  @doc """
  Creates a organization.

  ## Examples

      iex> create_organization(%{field: value})
      {:ok, %Organization{}}

      iex> create_organization(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_organization(attrs \\ %{}) do
    %Organization{}
    |> Organization.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a organization.

  ## Examples

      iex> update_organization(organization, %{field: new_value})
      {:ok, %Organization{}}

      iex> update_organization(organization, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_organization(%Organization{} = organization, attrs) do
    organization
    |> Organization.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a Organization.

  ## Examples

      iex> delete_organization(organization)
      {:ok, %Organization{}}

      iex> delete_organization(organization)
      {:error, %Ecto.Changeset{}}

  """
  def delete_organization(%Organization{} = organization) do
    Repo.delete(organization)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking organization changes.

  ## Examples

      iex> change_organization(organization)
      %Ecto.Changeset{source: %Organization{}}

  """
  def change_organization(%Organization{} = organization) do
    Organization.changeset(organization, %{})
  end

  @doc """
  Gets a single broker.

  Raises `Ecto.NoResultsError` if the Broker does not exist.

  ## Examples

      iex> get_broker!(123)
      %Broker{}

      iex> get_broker!(456)
      ** (Ecto.NoResultsError)

  """
  def get_broker!(id), do: Repo.get!(Broker, id)

  @doc """
  Creates a broker.

  ## Examples

      iex> create_broker(%{field: value})
      {:ok, %Broker{}}

      iex> create_broker(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_broker(attrs \\ %{}) do
    %Broker{}
    |> Broker.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a broker.

  ## Examples

      iex> update_broker(broker, %{field: new_value})
      {:ok, %Broker{}}

      iex> update_broker(broker, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_broker(%Broker{} = broker, attrs) do
    broker
    |> Broker.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking broker changes.

  ## Examples

      iex> change_broker(broker)
      %Ecto.Changeset{source: %Broker{}}

  """

  def signup_user(params, user_map) do
    Organization.signup_user_changeset(params, user_map) |> Repo.transaction()
  end

  def signup_invited_user(params, invite, user_map) do
    Organization.signup_invited_user_changeset(params, invite, user_map) |> Repo.transaction()
  end

  def whatsapp_signup_user(params, credential, user_map) do
    Organization.whatsapp_signup_user_changeset(params, credential, user_map) |> Repo.transaction()
  end

  def auto_assign_broker(org_id, broker_id) do
    Organization.auto_assign_broker(org_id, broker_id)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking broker changes.

  ## Examples

      iex> change_broker(broker)
      %Ecto.Changeset{source: %Broker{}}

  """
  def update_profile(logged_in_user, params) do
    user_map = Utils.get_user_map(logged_in_user)
    uuid = logged_in_user[:uuid]
    credential = Accounts.get_credential_by_uuid(uuid)
    broker_id = credential.broker_id

    is_pan_invalid =
      if not is_nil(params["pan"]) do
        !Utils.validate_pan(params["pan"])
      else
        false
      end

    is_rera_invalid = !Broker.validate_rera(params["rera"], params["rera_name"], broker_id)

    cond do
      is_pan_invalid ->
        {:error, "pan is invalid"}

      is_rera_invalid ->
        {:error, "rera is invalid"}

      true ->
        response = Broker.update_profile_changeset(params, credential, user_map) |> Repo.transaction()
        credential = Accounts.get_credential_by_uuid(uuid)

        Exq.enqueue(Exq, "sendbird", BnApis.UpdateUserOnSendbird, [
          Credential.get_sendbird_payload(credential, true),
          credential.uuid
        ])

        response
    end
  end

  def update_profile_pic(logged_in_user, params) do
    user_map = Utils.get_user_map(logged_in_user)
    uuid = logged_in_user[:uuid]
    credential = Accounts.get_credential_by_uuid(uuid)

    case Broker.update_profile_pic_changeset(params, credential) |> AuditedRepo.update(user_map) do
      {:ok, broker} ->
        credential = Accounts.get_credential_by_uuid(uuid)

        Exq.enqueue(Exq, "sendbird", BnApis.UpdateUserOnSendbird, [
          Credential.get_sendbird_payload(credential, true),
          credential.uuid
        ])

        {:ok, broker}

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  def update_pan_pic(logged_in_user, params) do
    user_map = Utils.get_user_map(logged_in_user)
    uuid = logged_in_user[:uuid]
    credential = Accounts.get_credential_by_uuid(uuid)

    case Broker.update_pan_pic_changeset(params, credential) |> AuditedRepo.update(user_map) do
      {:ok, broker} -> {:ok, broker}
      {:error, changeset} -> {:error, changeset}
    end
  end

  def update_rera_file(logged_in_user, params) do
    user_map = Utils.get_user_map(logged_in_user)
    uuid = logged_in_user[:uuid]
    credential = Accounts.get_credential_by_uuid(uuid)

    case Broker.update_rera_file_changeset(params, credential) |> AuditedRepo.update(user_map) do
      {:ok, broker} -> {:ok, broker}
      {:error, changeset} -> {:error, changeset}
    end
  end

  def send_invite(logged_in_user, params) do
    with {:ok, _phone_number, _country_code} <- Phone.parse_phone_number(params),
         {:admin, true} <- {:admin, logged_in_user.broker_role_id == BrokerRole.admin().id} do
      Organization.invite(logged_in_user, params)
    else
      {:admin, false} -> {:error, :invalid_access}
      error -> error
    end
  end

  def resend_invite(logged_in_user, params) do
    if logged_in_user.broker_role_id == BrokerRole.admin().id,
      do: Organization.resend_invite(logged_in_user, params),
      else: {:error, :invalid_access}
  end

  def cancel_invite(logged_in_user, params) do
    if logged_in_user.broker_role_id == BrokerRole.admin().id,
      do: Organization.cancel_invite(logged_in_user, params),
      else: {:error, :invalid_access}
  end

  def get_team(organization_id) do
    admins = Organization.admin_members_query(organization_id) |> Repo.all()
    chhotus = Organization.chhotus_members_query(organization_id) |> Repo.all()
    pendings = Invite.pending_members_query(organization_id) |> Repo.all()

    {:ok, {admins, chhotus, pendings}}
  end

  def successor_list(org_id, cred_id, params, page) do
    leave = params["type"] == "remove"

    Credential
    |> join(:left, [c], b in Broker, on: c.broker_id == b.id)
    |> where([c, b], c.active == true and c.organization_id == ^org_id)
    |> maybe_include_self(cred_id, leave)
    |> select([c, b], %{user_id: c.uuid, name: b.name, phone_number: c.phone_number, profile_image: b.profile_image, broker_role_id: c.broker_role_id})
    |> filter_successor_query(params)
    |> limit(@get_team_size)
    |> offset(^((page - 1) * (@get_team_size - 1)))
    |> order_by([c], asc: c.broker_role_id)
    |> Repo.all()
    |> add_pagination_info(page)
  end

  @doc """
  Old API still being used on app. This will always return page 1 data only.
  """
  def get_team_paginated(organization_id) do
    page = 1
    admins = Organization.admin_members_query(organization_id) |> limit(@get_team_size) |> offset(0) |> Repo.all()
    chhotus = Organization.chhotus_members_query(organization_id) |> limit(@get_team_size) |> offset(0) |> Repo.all()
    pendings = Invite.pending_members_query(organization_id) |> limit(@get_team_size) |> offset(0) |> Repo.all()

    {:ok, {add_pagination_info(admins, page), add_pagination_info(chhotus, page), add_pagination_info(pendings, page)}}
  end

  def get_team_data(organization_id, type, page) do
    case type do
      "admin" -> Organization.admin_members_query(organization_id)
      "chhotu" -> Organization.chhotus_members_query(organization_id)
      "pending_invite" -> Invite.pending_members_query(organization_id)
      "pending_request" -> fetch_pending_joining_requests(organization_id, page)
    end
    |> limit(@get_team_size)
    |> offset(^((page - 1) * (@get_team_size - 1)))
    |> Repo.all()
    |> add_pagination_info(page)
  end

  def get_team_members(logged_in_user) do
    organization_id = logged_in_user[:organization_id]
    broker_role_id = logged_in_user[:broker_role_id]

    if broker_role_id == BrokerRole.admin().id do
      Organization.active_team_members_query(organization_id)
      |> Repo.all()
      |> Enum.map(&team_member_structure/1)
    else
      [
        %{
          user_id: logged_in_user[:uuid],
          name: logged_in_user[:name],
          phone_number: logged_in_user[:phone_number],
          profile_image_url: logged_in_user[:profile_image_url]
        }
      ]
    end
  end

  def get_organization_brokers(organization_uuid, role_type_id \\ nil) do
    Organization.get_organization_brokers(organization_uuid, role_type_id)
  end

  def create_org_joining_request(
        _params = %{
          "org_id" => org_id,
          "admin_broker_id" => admin_broker_id
        },
        requestor_broker_id,
        requestor_cred_id,
        user_map
      ) do
    broker = Broker.fetch_broker_from_id(requestor_broker_id)
    admin_broker = Broker.fetch_broker_from_id(admin_broker_id)
    admin_rera = if not is_nil(admin_broker), do: admin_broker.rera, else: nil
    admin_rera_name = if not is_nil(admin_broker), do: admin_broker.rera_name, else: nil
    admin_rera_file = if not is_nil(admin_broker), do: admin_broker.rera_file, else: nil
    admin_rera_file_url = parse_rera_file(admin_rera_file)

    request_params = %{
      "requestor_cred_id" => requestor_cred_id,
      "organization_id" => org_id
    }

    rera_params = %{
      "rera" => admin_rera,
      "rera_name" => admin_rera_name,
      "rera_file" => admin_rera_file_url
    }

    with {:ok, joining_request} <- OrgJoiningRequests.create_org_joining_request(request_params),
         {:ok, _broker} <- Broker.update_broker_rera(rera_params, broker, user_map) do
      {:ok, joining_request}
    end
  end

  def create_org_joining_request(_params, _requestor_broker_id, _requestor_cred_id, _user_map), do: {:error, "Invalid params"}

  def approve_org_joining_request(joining_request_id, broker_role_id, processed_by_cred_id, user_map) do
    processed_by_cred = Credential |> Repo.get_by(id: processed_by_cred_id)

    if processed_by_cred.broker_role_id == BrokerRole.admin().id do
      broker_role_id = if is_binary(broker_role_id), do: String.to_integer(broker_role_id), else: broker_role_id

      with {:ok, joining_request} <- OrgJoiningRequests.approve_org_joining_request(joining_request_id, processed_by_cred_id),
           {:ok, _credential} <- Credential.update_broker_organization(joining_request, broker_role_id, user_map) do
        {:ok, joining_request}
      end
    else
      {:error, "Operation not authorized."}
    end
  end

  def reject_org_joining_request(joining_request_id, processed_by_cred_id, user_map) do
    processed_by_cred = Credential |> Repo.get_by(id: processed_by_cred_id)

    if processed_by_cred.broker_role_id == BrokerRole.admin().id do
      with {:ok, joining_request} <- OrgJoiningRequests.reject_org_joining_request(joining_request_id, processed_by_cred_id) do
        requestor_cred = Credential |> Repo.get_by(id: joining_request.requestor_cred_id)
        broker = if not is_nil(requestor_cred), do: Broker.fetch_broker_from_id(requestor_cred.broker_id), else: nil

        rera_params = %{
          "rera" => nil,
          "rera_name" => nil,
          "rera_file" => nil
        }

        Broker.update_broker_rera(rera_params, broker, user_map)
        |> case do
          {:ok, _broker} -> {:ok, joining_request}
          {:error, error} -> {:error, error}
        end
      end
    else
      {:error, "Operation not authorized."}
    end
  end

  def fetch_joining_request(joining_request_id) do
    OrgJoiningRequests.fetch_org_joining_request_by_id(joining_request_id)
    |> create_joining_request_map()
  end

  def fetch_pending_joining_requests(organization_id, page) do
    {:ok, joining_requests_list} = OrgJoiningRequests.fetch_pending_org_joining_requests(organization_id, page)

    if is_nil(page) do
      {:ok, joining_requests_list}
    else
      next = if @get_team_size - length(joining_requests_list) == 0, do: page + 1, else: -1
      joining_requests_list = if next > 0, do: List.delete_at(joining_requests_list, -1), else: joining_requests_list

      {:ok, %{data: joining_requests_list, next: next}}
    end
  end

  def cancel_org_joining_request(joining_request_id, cred_id, user_map) do
    with {:ok, joining_request} <- OrgJoiningRequests.cancel_org_joining_request(joining_request_id, cred_id) do
      cred = Credential |> Repo.get_by(id: cred_id)
      broker = if not is_nil(cred), do: Broker.fetch_broker_from_id(cred.broker_id), else: nil

      rera_params = %{
        "rera" => nil,
        "rera_name" => nil,
        "rera_file" => nil
      }

      Broker.update_broker_rera(rera_params, broker, user_map)
      |> case do
        {:ok, _broker} -> {:ok, joining_request}
        {:error, error} -> {:error, error}
      end
    end
  end

  def fetch_pending_org_joining_requests_for_credential(cred_id) do
    OrgJoiningRequests.fetch_pending_org_joining_requests_for_credential(cred_id)
  end

  def create_joining_request_map(nil), do: nil

  def create_joining_request_map(joining_request) do
    joining_request = joining_request |> Repo.preload([:requestor_cred, requestor_cred: [:broker]])

    %{
      joining_request_id: joining_request.id,
      status: joining_request.status,
      active: joining_request.active,
      organization_id: joining_request.organization_id,
      requestor_cred_id: joining_request.requestor_cred_id,
      processed_by_cred_id: joining_request.processed_by_cred_id,
      requestor_broker_id: joining_request.requestor_cred.broker_id,
      requestor_name: joining_request.requestor_cred.broker.name,
      requestor_phone_number: joining_request.requestor_cred.phone_number
    }
  end

  defp filter_successor_query(query, params) do
    where(query, ^filter_successor_query(params))
  end

  defp filter_successor_query(filter) do
    Enum.reduce(filter, dynamic(true), fn
      {_, entry}, dynamic when entry in ["", nil] ->
        dynamic

      {"query", query}, dynamic ->
        dynamic([c, b], ^dynamic and (like(c.phone_number, ^"%#{query}%") or ilike(b.name, ^"%#{query}%")))

      _, dynamic ->
        dynamic
    end)
  end

  defp team_member_structure(member) do
    profile_image = member.profile_image
    profile_pic_url = if !is_nil(profile_image) && !is_nil(profile_image["url"]), do: S3Helper.get_imgix_url(profile_image["url"])
    member |> Map.merge(%{profile_image_url: profile_pic_url})
  end

  defp parse_rera_file(rera_file) when rera_file in ["", nil], do: nil
  defp parse_rera_file(%{"url" => url}), do: url
  defp parse_rera_file(%{url: url}), do: url

  def add_pagination_info(list, page) do
    next = if @get_team_size - length(list) == 0, do: page + 1, else: -1
    data = if next > 0, do: List.delete_at(list, -1), else: list
    %{data: data, next: next}
  end

  defp maybe_include_self(query, cred_id, false),
    do: where(query, [c], c.active == true and c.id != ^cred_id)

  defp maybe_include_self(query, _cred_id, _), do: query
end
