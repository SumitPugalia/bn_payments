defmodule BnApis.Accounts.Invite do
  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query

  alias BnApis.Repo
  alias BnApis.Helpers.FormHelper
  alias BnApis.Accounts.{Credential, Invite, InviteStatus}
  alias BnApis.Organizations.{Organization, Broker}

  schema "brokers_invites" do
    field :uuid, Ecto.UUID, read_after_writes: true
    field :broker_name, :string
    field :broker_role_id, :integer
    field :phone_number, :string
    field :country_code, :string, default: "+91"
    field :invite_status_id, :id
    field :invited_by_id, :id

    timestamps()
  end

  @required [:phone_number, :broker_role_id, :invited_by_id, :invite_status_id, :country_code]
  @fields @required ++ [:broker_name]

  @doc false
  def changeset(invite, attrs) do
    invite
    |> cast(attrs, @fields)
    |> validate_required(@required)
    |> foreign_key_constraint(:invite_status_id)
    |> foreign_key_constraint(:invited_by_id)
    |> FormHelper.validate_phone_number(:phone_number)
    |> unique_constraint(:phone_number,
      name: :invited_by_to_phone_number_uniq_index,
      message: "$An invitation is already pending for this phone number"
    )
  end

  def changeset(attrs) do
    %__MODULE__{}
    |> changeset(attrs)
  end

  def new_invites_query(phone_number, country_code) do
    new_status_ids = [InviteStatus.new().id, InviteStatus.tried().id, InviteStatus.otp_verified().id]

    Invite
    |> where(
      [i],
      i.phone_number == ^phone_number and i.country_code == ^country_code and
        i.invite_status_id in ^new_status_ids
    )
  end

  def invite_select_query(query) do
    query
    |> join(:inner, [i], invitor in Credential, on: i.invited_by_id == invitor.id)
    |> join(:inner, [i, invitor], org in Organization, on: invitor.organization_id == org.id)
    |> join(:inner, [i, invitor, org], invitor_info in Broker, on: invitor.broker_id == invitor_info.id)
    |> select([i, invitor, invitor_org, invitor_info], %{
      invited_by_name: invitor_info.name,
      # invited_by_id: i.invited_by_id,
      organization_id: invitor_org.id,
      organization_name: invitor_org.name,
      broker_role_id: i.broker_role_id,
      broker_name: i.broker_name,
      profile_pic_url: invitor_info.profile_image,
      org_address: invitor_org.firm_address,
      invitor_phone_number: invitor.phone_number,
      sent_date: i.inserted_at
    })
  end

  def mark_invites_as_tried_changeset(phone_number, country_code) do
    new_invites_query(phone_number, country_code)
    |> update(set: [invite_status_id: ^InviteStatus.tried().id])
  end

  def mark_invites_as_otp_verified_changeset(phone_number, country_code) do
    new_invites_query(phone_number, country_code)
    |> update(set: [invite_status_id: ^InviteStatus.otp_verified().id])
  end

  def mark_invite_as_changeset(invite, invite_status_id) do
    invite
    |> change(invite_status_id: invite_status_id)
  end

  def check_invitation(phone_number, country_code, org_id) do
    pending_status_ids = [InviteStatus.new().id, InviteStatus.tried().id, InviteStatus.otp_verified().id]

    Invite
    |> join(:inner, [i], invitor in Credential, on: i.invited_by_id == invitor.id)
    |> join(:inner, [i, invitor], org in Organization, on: invitor.organization_id == org.id)
    |> where(
      [i, invitor, org],
      i.phone_number == ^phone_number and org.id == ^org_id and i.invite_status_id in ^pending_status_ids and
        i.country_code == ^country_code
    )
    |> Repo.all()
    |> List.last()
  end

  def pending_members_query(org_id) do
    pending_status_ids = [InviteStatus.new().id, InviteStatus.tried().id, InviteStatus.otp_verified().id]

    Invite
    |> join(:inner, [i], invitor in Credential, on: i.invited_by_id == invitor.id)
    |> join(:inner, [i, invitor], org in Organization, on: invitor.organization_id == org.id)
    |> where([i, invitor, org], i.invite_status_id in ^pending_status_ids and org.id == ^org_id)
  end

  def cancel_other_invites(phone_number, country_code) do
    pending_status_ids = [InviteStatus.new().id, InviteStatus.tried().id, InviteStatus.otp_verified().id]
    cancelled_invite_id = InviteStatus.cancelled().id

    Invite
    |> where(
      [i],
      i.phone_number == ^phone_number and i.country_code == ^country_code and i.invite_status_id in ^pending_status_ids
    )
    |> Ecto.Query.update(set: [invite_status_id: ^cancelled_invite_id])
    |> Repo.update_all([])
  end

  def fetch_invited_broker(phone_number, country_code) do
    Invite
    |> where([i], i.phone_number == ^phone_number and i.country_code == ^country_code)
    |> last(:inserted_at)
    |> Repo.one()
  end
end
