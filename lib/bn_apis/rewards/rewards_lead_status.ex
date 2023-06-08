defmodule BnApis.Rewards.RewardsLeadStatus do
  use Ecto.Schema
  import Ecto.Changeset
  alias BnApis.Repo
  alias BnApis.Rewards.RewardsLead
  alias BnApis.Rewards.RewardsLeadStatus
  alias BnApis.Rewards.Status
  alias BnApis.Accounts.{DeveloperPocCredential, EmployeeCredential}

  schema "rewards_lead_statuses" do
    field(:status_id, :integer)
    field(:failure_reason_id, :integer)
    field(:failure_note, :string)
    belongs_to(:rewards_lead, RewardsLead)
    belongs_to(:developer_poc_credential, DeveloperPocCredential)
    field(:app_version, :string)
    field(:device_manufacturer, :string)
    field(:device_model, :string)
    field(:device_os_version, :string)
    belongs_to(:employee_credential, EmployeeCredential)
    timestamps()
  end

  @required [:status_id, :rewards_lead_id]
  @optional [
    :developer_poc_credential_id,
    :failure_reason_id,
    :failure_note,
    :app_version,
    :device_manufacturer,
    :device_model,
    :device_os_version,
    :employee_credential_id
  ]

  defp changeset(rewards_lead_status, attrs) do
    # internal changeset, not to be used directly
    rewards_lead_status
    |> cast(attrs, @required ++ @optional)
    |> validate_required(@required)
    |> foreign_key_constraint(:rewards_lead_id)
  end

  def developer_poc_status_changeset(rewards_lead_status, attrs) do
    rewards_lead_status
    |> changeset(attrs)
    |> foreign_key_constraint(:developer_poc_credential_id)
  end

  def manager_status_changeset(rewards_lead_status, attrs) do
    rewards_lead_status
    |> changeset(attrs)
    |> foreign_key_constraint(:employee_credential_id)
  end

  def backend_poc_status_changeset(rewards_lead_status, attrs), do: changeset(rewards_lead_status, attrs)

  def get_rewards_lead_status(id) do
    Repo.get_by(RewardsLeadStatus, id: id)
  end

  def create_rewards_lead_status!(
        rewards_lead,
        status_id
      ) do
    rewards_lead = Repo.preload(rewards_lead, [:latest_status])

    changeset =
      RewardsLeadStatus.developer_poc_status_changeset(%RewardsLeadStatus{}, %{
        rewards_lead_id: rewards_lead.id,
        status_id: status_id
      })
      |> validate_status_change(rewards_lead.latest_status)

    rewards_lead_status = Repo.insert!(changeset)
    RewardsLead.update_latest_status!(rewards_lead, rewards_lead_status.id)
    rewards_lead_status
  end

  def create_rewards_lead_status_by_poc!(
        rewards_lead,
        status_id,
        developer_poc_credential_id,
        failure_reason_id \\ nil,
        failure_note \\ nil,
        device_info \\ %{}
      ) do
    rewards_lead = Repo.preload(rewards_lead, [:latest_status])

    changeset =
      RewardsLeadStatus.developer_poc_status_changeset(%RewardsLeadStatus{}, %{
        rewards_lead_id: rewards_lead.id,
        status_id: status_id,
        developer_poc_credential_id: developer_poc_credential_id,
        failure_reason_id: failure_reason_id,
        failure_note: failure_note,
        app_version: device_info["build-version"],
        device_manufacturer: device_info["manufacturer"],
        device_model: device_info["model"],
        device_os_version: device_info["os-version"]
      })
      |> validate_status_change(rewards_lead.latest_status)

    rewards_lead_status = Repo.insert!(changeset)
    RewardsLead.update_latest_status!(rewards_lead, rewards_lead_status.id)
    rewards_lead_status
  end

  def create_rewards_lead_status_by_manager!(
        rewards_lead,
        status_id,
        employee_credential_id,
        failure_reason_id \\ nil,
        failure_note \\ nil
      ) do
    rewards_lead = Repo.preload(rewards_lead, [:latest_status])

    changeset =
      RewardsLeadStatus.manager_status_changeset(%RewardsLeadStatus{}, %{
        rewards_lead_id: rewards_lead.id,
        status_id: status_id,
        employee_credential_id: employee_credential_id,
        failure_reason_id: failure_reason_id,
        failure_note: failure_note
      })
      |> validate_status_change(rewards_lead.latest_status)

    rewards_lead_status = Repo.insert!(changeset)
    RewardsLead.update_latest_status!(rewards_lead, rewards_lead_status.id)
    rewards_lead_status
  end

  def create_rewards_lead_status_by_backend!(
        rewards_lead,
        status_id,
        failure_note \\ nil
      ) do
    rewards_lead = Repo.preload(rewards_lead, [:latest_status])

    changeset =
      RewardsLeadStatus.backend_poc_status_changeset(%RewardsLeadStatus{}, %{
        rewards_lead_id: rewards_lead.id,
        status_id: status_id,
        failure_note: failure_note
      })
      |> validate_status_change(rewards_lead.latest_status)

    rewards_lead_status = Repo.insert!(changeset)
    RewardsLead.update_latest_status!(rewards_lead, rewards_lead_status.id)
    rewards_lead_status
  end

  def validate_status_change(changeset, %__MODULE__{status_id: old_status_id}),
    do: validate_status_change(changeset, old_status_id)

  def validate_status_change(changeset, old_status_id) do
    old_state = if old_status_id == nil, do: nil, else: Status.get_status_from_id(old_status_id)
    new_state = get_field(changeset, :status_id) |> Status.get_status_from_id()

    if valid_status_change(old_state, new_state),
      do: changeset,
      else: add_error(changeset, :status_id, "Cannot change status from #{old_state} to #{new_state}")
  end

  defp valid_status_change(state, state) when not is_nil(state), do: false

  defp valid_status_change(old_state, new_state),
    do: Status.valid_status_change(old_state) |> Enum.any?(&(&1 == new_state))
end
