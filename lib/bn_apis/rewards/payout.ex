defmodule BnApis.Rewards.Payout do
  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query
  alias BnApis.Repo
  alias BnApis.Rewards.{Payout, PayoutStatus, RewardsLead, RewardsLeadStatus, Status, PayoutFailureReason}
  alias BnApis.Stories.Story
  alias BnApis.Accounts.DeveloperPocCredential
  alias BnApis.Accounts.Schema.GatewayToCityMapping
  alias BnApis.Organizations.Broker

  schema "payouts" do
    field(:payout_id, :string)
    field(:status, :string)
    field(:account_number, :string)
    field(:utr, :string)
    field(:fund_account_id, :string)
    field(:amount, :float)
    field(:created_at, :integer)
    field(:purpose, :string)
    field(:mode, :string)
    field(:reference_id, :string)
    field(:currency, :string)
    field(:rewards_lead_name, :string)
    field(:broker_phone_number, :string)
    field(:story_name, :string)
    field(:developer_poc_name, :string)
    field(:developer_poc_number, :string)
    field(:failure_reason, :string)
    field(:gateway_name, :string)

    belongs_to(:rewards_lead, RewardsLead)
    belongs_to(:broker, Broker)
    belongs_to(:story, Story)
    belongs_to(:developer_poc_credential, DeveloperPocCredential)

    has_many(:payout_statuses, PayoutStatus, foreign_key: :rewards_payout_id)

    timestamps()
  end

  @processed_status "processed"
  @reversed_status "reversed"

  @required [
    :payout_id,
    :status,
    :account_number,
    :fund_account_id,
    :amount,
    :purpose,
    :mode,
    :rewards_lead_id,
    :broker_id,
    :story_id,
    :developer_poc_credential_id,
    :gateway_name
  ]
  @optional [
    :currency,
    :utr,
    :reference_id,
    :created_at,
    :failure_reason,
    :broker_phone_number,
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
    |> foreign_key_constraint(:broker_id)
    |> foreign_key_constraint(:rewards_lead_id)
    |> foreign_key_constraint(:story_id)
  end

  def payout_status_changeset(payout, attrs) do
    payout
    |> cast(attrs, [:status])
    |> validate_required([:status])
    |> foreign_key_constraint(:rewards_lead_id)
    |> foreign_key_constraint(:developer_poc_credential_id)
    |> foreign_key_constraint(:broker_id)
    |> foreign_key_constraint(:story_id)
  end

  def create_rewards_payout!(params) do
    ch =
      Payout.changeset(%Payout{}, %{
        payout_id: params[:payout_id],
        status: params[:status],
        amount: params[:amount],
        currency: params[:currency],
        account_number: params[:account_number],
        utr: params[:utr],
        fund_account_id: params[:fund_account_id],
        mode: params[:mode],
        reference_id: params[:reference_id],
        created_at: params[:created_at],
        failure_reason: params[:failure_reason],
        purpose: params[:purpose],
        broker_phone_number: params[:broker_phone_number],
        rewards_lead_id: params[:rewards_lead_id],
        broker_id: params[:broker_id],
        story_id: params[:story_id],
        developer_poc_credential_id: params[:developer_poc_credential_id],
        rewards_lead_name: params[:rewards_lead_name],
        developer_poc_name: params[:developer_poc_name],
        developer_poc_number: params[:developer_poc_number],
        story_name: params[:story_name],
        gateway_name: Map.get(params, :gateway_name, GatewayToCityMapping.razorpay())
      })

    payout = Repo.insert!(ch)

    PayoutStatus.create_payout_status!(
      payout,
      params[:status],
      params[:razorpay_data]
    )

    if params[:status] == @processed_status do
      rewards_lead = Repo.get_by(RewardsLead, id: payout.rewards_lead_id)
      reward_lead_status_id = 4

      RewardsLeadStatus.create_rewards_lead_status_by_backend!(
        rewards_lead,
        reward_lead_status_id
      )
    end

    if params[:status] == @reversed_status do
      send_payout_failure_whatsapp_notification(
        payout.id,
        params[:rewards_lead_name],
        params[:broker_phone_number],
        params[:failure_reason]
      )
    end

    payout
  end

  def update_status!(%Payout{} = payout, status, params) do
    ch =
      Payout.payout_status_changeset(payout, %{
        status: status
      })

    Repo.update!(ch)
    PayoutStatus.create_payout_status!(payout, status, params)

    case status do
      @processed_status ->
        rewards_lead = Repo.get_by(RewardsLead, id: payout.rewards_lead_id)
        reward_lead_status_id = 4

        RewardsLeadStatus.create_rewards_lead_status_by_backend!(
          rewards_lead,
          reward_lead_status_id
        )

      @reversed_status ->
        send_payout_failure_whatsapp_notification(
          payout.id,
          params[:rewards_lead_name],
          params[:broker_phone_number],
          params[:failure_reason]
        )
    end
  end

  def get_payout_failure_reason(lead) do
    lead_status = lead.latest_status
    get_latest_approved_payout(lead_status.status_id == Status.get_status_id("approved"), lead)
  end

  defp get_latest_approved_payout(false, _lead), do: nil

  defp get_latest_approved_payout(true, lead) do
    payout =
      Payout
      |> where([p], p.rewards_lead_id == ^lead.id)
      |> select([p], %{id: p.id, status: p.status, failure_reason: p.failure_reason, updated_at: p.updated_at})
      |> order_by(desc: :updated_at)
      |> limit(1)
      |> Repo.one()

    case payout do
      nil -> nil
      payout -> get_reversed_payout_failure_reason(payout.status == @reversed_status, payout)
    end
  end

  defp get_reversed_payout_failure_reason(false, _payout), do: nil

  defp get_reversed_payout_failure_reason(true, payout) do
    PayoutFailureReason.get_mapped_failure_reason(payout.failure_reason, payout.id)
  end

  def send_payout_failure_whatsapp_notification(
        payout_id,
        rewards_lead_name,
        broker_phone_number,
        failure_reason
      ) do
    failure_reason_map = PayoutFailureReason.get_mapped_failure_reason(failure_reason, payout_id)

    failure_reason_text = "Your site visit reward payment for #{rewards_lead_name} failed because of the following reason: #{failure_reason_map[:type]}. "

    additional_text =
      case failure_reason_map[:type] do
        "invalid_details" ->
          "Please update your UPI ID in Broker Network App. "

        "bank_error" ->
          "The payment will be reattempted."
      end

    message_text = failure_reason_text <> additional_text

    Exq.enqueue(Exq, "send_whatsapp_message", BnApis.Whatsapp.SendWhatsappMessageWorker, [
      broker_phone_number,
      "generic",
      [message_text]
    ])
  end
end
