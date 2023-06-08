defmodule BnApis.Rewards.EmployeePayout do
  use Ecto.Schema
  import Ecto.Changeset
  alias BnApis.Repo
  alias BnApis.Rewards.EmployeePayout
  alias BnApis.Rewards.EmployeePayoutStatus
  alias BnApis.Stories.Story
  alias BnApis.Accounts.DeveloperPocCredential
  alias BnApis.Rewards.RewardsLead
  alias BnApis.Rewards.RewardsLeadStatus
  alias BnApis.Accounts.EmployeeCredential
  alias BnApis.Accounts.Schema.GatewayToCityMapping

  schema "employee_payouts" do
    field(:payout_id, :string)
    field(:status, :string)
    field(:account_number, :string)
    field(:utr, :string)
    field(:fund_account_id, :string)
    field(:amount, :float)
    field(:purpose, :string)
    field(:mode, :string)
    field(:reference_id, :string)
    field(:currency, :string)
    field(:rewards_lead_name, :string)
    field(:story_name, :string)
    field(:developer_poc_name, :string)
    field(:developer_poc_number, :string)
    field :gateway_name, :string

    belongs_to(:rewards_lead, RewardsLead)
    belongs_to(:employee_credential, EmployeeCredential)
    belongs_to(:story, Story)
    belongs_to(:developer_poc_credential, DeveloperPocCredential)

    has_many(:employee_payout_statuses, EmployeePayoutStatus, foreign_key: :rewards_employee_payout_id)

    timestamps()
  end

  @processed_status "processed"

  @required [
    :payout_id,
    :status,
    :account_number,
    :fund_account_id,
    :amount,
    :purpose,
    :mode,
    :rewards_lead_id,
    :employee_credential_id,
    :story_id,
    :developer_poc_credential_id,
    :gateway_name
  ]
  @optional [
    :currency,
    :utr,
    :reference_id,
    :rewards_lead_name,
    :developer_poc_name,
    :developer_poc_number,
    :story_name
  ]

  @doc false
  def changeset(payout, attrs) do
    payout
    |> cast(attrs, @required ++ @optional)
    |> validate_required(@required)
    |> foreign_key_constraint(:developer_poc_credential_id)
    |> foreign_key_constraint(:employee_credential_id)
    |> foreign_key_constraint(:rewards_lead_id)
    |> foreign_key_constraint(:story_id)
  end

  def employee_payout_status_changeset(payout, attrs) do
    payout
    |> cast(attrs, [:status])
    |> validate_required([:status])
    |> foreign_key_constraint(:rewards_lead_id)
    |> foreign_key_constraint(:developer_poc_credential_id)
    |> foreign_key_constraint(:employee_credential_id)
    |> foreign_key_constraint(:story_id)
  end

  def create_rewards_employee_payout!(params) do
    ch =
      EmployeePayout.changeset(%EmployeePayout{}, %{
        payout_id: params[:payout_id],
        status: params[:status],
        amount: params[:amount],
        currency: params[:currency],
        account_number: params[:account_number],
        utr: params[:utr],
        fund_account_id: params[:fund_account_id],
        mode: params[:mode],
        reference_id: params[:reference_id],
        purpose: params[:purpose],
        rewards_lead_id: params[:rewards_lead_id],
        employee_credential_id: params[:employee_credential_id],
        story_id: params[:story_id],
        developer_poc_credential_id: params[:developer_poc_credential_id],
        rewards_lead_name: params[:rewards_lead_name],
        developer_poc_name: params[:developer_poc_name],
        developer_poc_number: params[:developer_poc_number],
        story_name: params[:story_name],
        gateway_name: Map.get(params, :gateway_name, GatewayToCityMapping.razorpay())
      })

    employee_payout = Repo.insert!(ch)

    EmployeePayoutStatus.create_employee_payout_status!(
      employee_payout,
      params[:status],
      params[:razorpay_data]
    )

    if params[:status] == @processed_status do
      rewards_lead = Repo.get_by(RewardsLead, id: employee_payout.rewards_lead_id) |> Repo.preload([:latest_status])
      reward_lead_status_id = 5

      changeset =
        RewardsLeadStatus.backend_poc_status_changeset(%RewardsLeadStatus{}, %{
          rewards_lead_id: rewards_lead.id,
          status_id: reward_lead_status_id
        })
        |> RewardsLeadStatus.validate_status_change(rewards_lead.latest_status)

      Repo.insert!(changeset)
    end

    employee_payout
  end

  def update_status!(%EmployeePayout{} = employee_payout, status, params) do
    ch =
      EmployeePayout.employee_payout_status_changeset(employee_payout, %{
        status: status
      })

    Repo.update!(ch)
    EmployeePayoutStatus.create_employee_payout_status!(employee_payout, status, params)

    if status == @processed_status do
      rewards_lead = Repo.get_by(RewardsLead, id: employee_payout.rewards_lead_id) |> Repo.preload([:latest_status])
      reward_lead_status_id = 5

      changeset =
        RewardsLeadStatus.backend_poc_status_changeset(%RewardsLeadStatus{}, %{
          rewards_lead_id: rewards_lead.id,
          status_id: reward_lead_status_id
        })
        |> RewardsLeadStatus.validate_status_change(rewards_lead.latest_status)

      Repo.insert!(changeset)
    end
  end
end
