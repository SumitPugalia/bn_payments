defmodule Mix.Tasks.UpdateMissedPayouts do
  use Mix.Task
  alias BnApis.Helpers.ApplicationHelper
  alias BnApis.Helpers.ExternalApiHelper
  alias BnApis.Rewards.Payout
  alias BnApis.Rewards.EmployeePayout
  alias BnApis.Rewards.RewardsLead
  alias BnApis.Accounts.Credential
  alias BnApis.Stories.StoryDeveloperPocMapping
  alias BnApis.Repo

  @payout_ids [
    "pout_JDaoP7IBg3W1hu",
    "pout_JDbfvm8pv2N9D2",
    "pout_KKuuR5FpKeX7lW",
    "pout_KKuuFBNnBDKsPY",
    "pout_KKuuAdEpGBIwxm",
    "pout_KKuu656rWLOgS3",
    "pout_KKuuUBxrzrNfvQ",
    "pout_KKuum2zg9t5CYf",
    "pout_KKuuI7r1slwCIo",
    "pout_KKuusPPJUzmmtO",
    "pout_KKuuKVZsihpOzN",
    "pout_KKuud5ZppLIX1k",
    "pout_KKuujMjX3wJXkh",
    "pout_KKuuGs36AcWWmP",
    "pout_KKuuL8d61mouW2",
    "pout_KKuuj9Or31MxuW",
    "pout_KKuuZxsTmFyXX7",
    "pout_KKuuEFTFbYJWOF",
    "pout_KKuu9MFs05PU9f",
    "pout_KKuu4kC0Qd0Iij",
    "pout_KKuu8HOXKbzEkH",
    "pout_KKuuMehdIbF2Wb",
    "pout_KKuuqNeN0VjE39",
    "pout_KNh9IOEsruRhjZ"
  ]

  @shortdoc "update missed webhooks payouts"
  def run(_) do
    Mix.Task.run("app.start", [])
    update_payouts()
  end

  defp update_payouts() do
    channel = ApplicationHelper.get_slack_channel()
    account_number = ApplicationHelper.get_razorpay_account_number()

    ApplicationHelper.notify_on_slack(
      "Starting to update missed payouts",
      channel
    )

    @payout_ids
    |> Enum.each(fn payout_id ->
      try do
        auth_key = ApplicationHelper.get_razorpay_auth_key()

        {status_code, response} = ExternalApiHelper.get_razorpay_payout_details(payout_id, auth_key)

        if status_code == 200 and not is_nil(response) and not is_nil(response["amount"]) do
          rl = Repo.get(RewardsLead, response["reference_id"]) |> Repo.preload([:broker, :story, :latest_status, latest_status: [:developer_poc_credential]])

          if not is_nil(rl) do
            cred = Credential.get_credential_from_broker_id(rl.broker_id)
            cred = if is_nil(cred), do: Credential.get_any_credential_from_broker_id(rl.broker_id), else: cred

            developer_poc_credential =
              if not is_nil(rl.latest_status.developer_poc_credential),
                do: rl.latest_status.developer_poc_credential,
                else: StoryDeveloperPocMapping.get_any_poc_details_from_story_id(rl.story_id)

            if is_nil(developer_poc_credential) do
              ApplicationHelper.notify_on_slack(
                "Could not find developer poc for #{rl.id}",
                channel
              )
            end

            if response["amount"] == 30000 and not is_nil(developer_poc_credential) do
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

            if response["amount"] == 10000 and not is_nil(developer_poc_credential) do
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
          end

          Process.sleep(500)
        end
      rescue
        e in _ ->
          ApplicationHelper.notify_on_slack(
            "Error in webhooks reconcilliation worker for lead #{payout_id} because of #{Exception.message(e)}",
            channel
          )
      end
    end)

    ApplicationHelper.notify_on_slack(
      "Finished to update missed payouts",
      channel
    )
  end
end
