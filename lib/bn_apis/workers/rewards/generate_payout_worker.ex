defmodule BnApis.Rewards.GeneratePayoutWorker do
  alias BnApis.Accounts.Credential
  alias BnApis.Rewards.RewardsLead
  alias BnApis.Helpers.ApplicationHelper
  alias BnApis.Rewards.Payout
  alias BnApis.PaymentGateway.API, as: PaymentGateway
  alias BnApis.Accounts.Schema.GatewayToCityMapping
  alias BnApis.Repo

  @payment_const %{
    "currency" => "INR",
    "amount" => 30000,
    "mode" => "UPI",
    "purpose" => "payout",
    "queue_if_low_balance" => true
  }
  @processed_status "processed"

  @denarii GatewayToCityMapping.denarri()
  @razorpay GatewayToCityMapping.razorpay()

  def perform(id, retry_payout_id \\ nil) do
    channel = ApplicationHelper.get_slack_channel()

    try do
      rewards_lead = Repo.get_by(RewardsLead, id: id) |> Repo.preload([:payouts, :latest_status])

      credential = Credential.get_any_credential_from_broker_id(rewards_lead.broker_id) |> Repo.preload([:organization])

      {uuid, credential} =
        if credential.organization.team_upi_cred_uuid do
          uuid = credential.organization.team_upi_cred_uuid

          {uuid, Repo.get_by(Credential, uuid: uuid) |> Repo.preload([:organization])}
        else
          {credential.uuid, credential}
        end

      payment_metadata = Credential.fetch_payout_metadata(uuid)

      if check_eligility_for_payout_creation(credential, rewards_lead, payment_metadata) do
        {status_code, response} = create_payout(payment_metadata, credential, rewards_lead, retry_payout_id)

        if status_code == 200 do
          params = get_params_for_payout(response, credential, rewards_lead, payment_gateway_name(payment_metadata))
          Payout.create_rewards_payout!(params)
        else
          error_description = get_error_description(response)

          ApplicationHelper.notify_on_slack(
            "Non-200 response -- #{error_description} -- from Razorpay for eligible lead when tried for Payout #{id}",
            channel
          )
        end
      else
        if rewards_lead.latest_status.status_id == 4 do
          ApplicationHelper.notify_on_slack("Error, <@U03MCEL5WU8> lead #{id} tried payment for already approved lead", channel)
        end
      end
    rescue
      e in _ ->
        ApplicationHelper.notify_on_slack(
          "Error in payout worker for lead #{id} because of #{Exception.message(e)} #{inspect(e)} stacktrace: #{inspect(__STACKTRACE__)}",
          channel
        )
    end
  end

  defp create_payout(
         _metadata = nil,
         %Credential{razorpay_contact_id: razorpay_contact_id, razorpay_fund_account_id: razorpay_fund_account_id} = _credential,
         rewards_lead,
         retry_payout_id
       )
       when not is_nil(razorpay_fund_account_id) and
              not is_nil(razorpay_contact_id),
       do: create_razorpay_payout(razorpay_fund_account_id, rewards_lead, retry_payout_id)

  defp create_payout(%{name: @razorpay, fund_account_id: fund_account_id}, _credential, rewards_lead, retry_payout_id),
    do: create_razorpay_payout(fund_account_id, rewards_lead, retry_payout_id)

  defp create_payout(
         %{name: @denarii, contact_id: contact_id, fund_account_id: fund_account_id},
         _credential,
         rewards_lead,
         retry_payout_id
       ),
       do:
         PaymentGateway.make_payment_via_denarri(
           contact_id,
           fund_account_id,
           @payment_const,
           rewards_lead.id,
           retry_payout_id
         )

  defp create_razorpay_payout(fund_account_id, rewards_lead, retry_payout_id) do
    PaymentGateway.create_razorpay_payout(
      fund_account_id,
      @payment_const,
      rewards_lead.id,
      "g",
      retry_payout_id
    )
  end

  defp check_eligility_for_payout_creation(credential, rewards_lead, payment_metadata) do
    is_legacy_nil? =
      is_nil(credential.razorpay_contact_id) or
        is_nil(credential.razorpay_fund_account_id)

    contains_payment_info? = if is_nil(payment_metadata), do: is_legacy_nil?, else: false

    cond do
      rewards_lead.latest_status.status_id == 4 ->
        false

      Enum.member?(
        Enum.map(rewards_lead.payouts, fn p -> p.status end),
        @processed_status
      ) ->
        false

      contains_payment_info? ->
        false

      true ->
        true
    end
  end

  defp get_params_for_payout(response, credential, rewards_lead, gateway_name) do
    rewards_lead = rewards_lead |> Repo.preload([:developer_poc_credential, :story])

    params = %{
      payout_id: response["id"],
      status: response["status"],
      account_number: ApplicationHelper.get_razorpay_account_number(),
      amount: response["amount"],
      purpose: response["purpose"],
      fund_account_id: response["fund_account_id"],
      currency: response["currency"],
      utr: response["utr"],
      mode: response["mode"],
      reference_id: response["reference_id"],
      created_at: response["created_at"],
      failure_reason: response["failure_reason"],
      broker_phone_number: credential.phone_number,
      rewards_lead_id: rewards_lead.id,
      broker_id: rewards_lead.broker_id,
      story_id: rewards_lead.story_id,
      developer_poc_credential_id: rewards_lead.developer_poc_credential_id,
      rewards_lead_name: rewards_lead.name,
      developer_poc_name: rewards_lead.developer_poc_credential.name,
      developer_poc_number: rewards_lead.developer_poc_credential.phone_number,
      story_name: rewards_lead.story.name,
      razorpay_data: response,
      gateway_name: gateway_name
    }

    params
  end

  defp payment_gateway_name(%{name: name}), do: name
  defp payment_gateway_name(_), do: @razorpay

  defp get_error_description(%{"error" => %{"description" => msg}}), do: msg
  defp get_error_description(error), do: inspect(error)
end
