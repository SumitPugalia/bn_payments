defmodule BnApis.Rewards.UpdatePayoutStatusForMissedWebhooks do
  import Ecto.Query
  alias BnApis.Repo

  alias BnApis.Helpers.{ApplicationHelper, ExternalApiHelper}
  alias BnApis.Rewards.RewardsLead
  alias BnApis.Rewards.RewardsLeadStatus
  alias BnApis.Accounts.Credential
  alias BnApis.Rewards.Payout
  alias BnApis.Rewards.EmployeePayout
  alias BnApis.Stories.StoryDeveloperPocMapping

  def perform() do
    rewards_leads =
      RewardsLead
      |> join(:inner, [rl], rls in RewardsLeadStatus, on: rl.latest_status_id == rls.id)
      |> where([rl, rls], rls.status_id == 3)
      |> Repo.all()
      |> Repo.preload([:broker, :story, :latest_status, latest_status: [:developer_poc_credential]])
      |> Enum.reverse()

    rewards_leads
    |> Enum.each(fn rl ->
      try do
        {_, payout_response} = ExternalApiHelper.get_payout_details_from_reference_id(rl.id)

        if payout_response && payout_response["items"] && payout_response["items"] |> length > 0 do
          response =
            payout_response["items"]
            |> Enum.filter(fn item -> item["amount"] == 30000 and item["status"] == "processed" end)
            |> List.first()

          account_number = ApplicationHelper.get_razorpay_account_number()
          cred = Credential.get_credential_from_broker_id(rl.broker_id)
          cred = if is_nil(cred), do: Credential.get_any_credential_from_broker_id(rl.broker_id), else: cred

          developer_poc_credential =
            if not is_nil(rl.latest_status.developer_poc_credential),
              do: rl.latest_status.developer_poc_credential,
              else: StoryDeveloperPocMapping.get_any_poc_details_from_story_id(rl.story_id)

          if not is_nil(response) and response["status"] == "processed" and not is_nil(developer_poc_credential) do
            payout_params = %{
              payout_id: response["id"],
              status: response["status"],
              amount: response["amount"],
              currency: response["currency"],
              account_number: account_number,
              utr: response["utr"],
              fund_account_id: response["fund_account_id"],
              mode: response["mode"],
              reference_id: response["reference_id"],
              created_at: response["created_at"],
              failure_reason: response["failure_reason"],
              purpose: response["purpose"],
              rewards_lead_id: rl.id,
              broker_id: rl.broker_id,
              story_id: rl.story_id,
              developer_poc_credential_id: developer_poc_credential.id,
              rewards_lead_name: rl.name,
              developer_poc_name: developer_poc_credential.name,
              developer_poc_number: developer_poc_credential.phone_number,
              story_name: rl.story.name,
              broker_phone_number: cred.phone_number,
              razorpay_data: response
            }

            Payout.create_rewards_payout!(payout_params)
          end

          response = payout_response["items"] |> Enum.filter(fn item -> item["amount"] == 10000 end) |> List.first()

          if not is_nil(response) and response["status"] == "processed" and not is_nil(developer_poc_credential) do
            payout_params = %{
              payout_id: response["id"],
              status: response["status"],
              amount: response["amount"],
              currency: response["currency"],
              account_number: account_number,
              utr: response["utr"],
              fund_account_id: response["fund_account_id"],
              mode: response["mode"],
              reference_id: response["reference_id"],
              created_at: response["created_at"],
              failure_reason: response["failure_reason"],
              purpose: response["purpose"],
              rewards_lead_id: rl.id,
              broker_id: rl.broker_id,
              story_id: rl.story_id,
              developer_poc_credential_id: developer_poc_credential.id,
              rewards_lead_name: rl.name,
              developer_poc_name: developer_poc_credential.name,
              developer_poc_number: developer_poc_credential.phone_number,
              story_name: rl.story.name,
              broker_phone_number: cred.phone_number,
              razorpay_data: response,
              employee_credential_id: rl.employee_credential_id
            }

            EmployeePayout.create_rewards_employee_payout!(payout_params)
          end

          Process.sleep(500)
        end
      rescue
        e in _ ->
          channel = ApplicationHelper.get_slack_channel()

          ApplicationHelper.notify_on_slack(
            "Error in webhooks reconcilliation worker for lead #{rl.id} because of #{Exception.message(e.message || e)}",
            channel
          )
      end
    end)
  end
end
