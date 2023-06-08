defmodule BnApis.Rewards.SendRewardsNotificationWorker do
  alias BnApis.Helpers.{FcmNotification, Utils}
  alias BnApis.Accounts.Credential
  alias BnApis.Rewards.RewardsLead
  alias BnApis.Rewards.Status
  alias BnApis.Repo
  import Ecto.Query

  def perform(id) do
    rewards_lead = Repo.get_by(RewardsLead, id: id)

    rewards_lead = rewards_lead |> Repo.preload([:latest_status, :employee_credential, :broker, :story, :developer_poc_credential])

    rewards_lead_status_identifier = Status.status_details(rewards_lead.latest_status.status_id)["identifier"]

    credential = Credential |> where([cr], cr.broker_id == ^rewards_lead.broker_id) |> Repo.all() |> Utils.get_active_fcm_credential()

    type = "REWARD_UPDATE"

    notification_data = get_notification_data(rewards_lead, rewards_lead_status_identifier)

    if not is_nil(notification_data) and not is_nil(credential) do
      FcmNotification.send_push(
        credential.fcm_id,
        %{data: notification_data, status: rewards_lead_status_identifier, type: type},
        credential.id,
        credential.notification_platform
      )
    else
      nil
    end
  end

  def get_notification_data(rewards_lead, rewards_lead_status_identifier) do
    case rewards_lead_status_identifier do
      "rejected" ->
        %{
          "title" => "Site Visit Rejected",
          "message" => get_sv_rejected_message(rewards_lead),
          "client_uuid" => rewards_lead.id
        }

      "approved" ->
        %{
          "title" => "Site Visit Approved",
          "message" => get_reward_approved_message(rewards_lead),
          "client_uuid" => rewards_lead.id
        }

      "reward_received" ->
        %{
          "title" => "Rs 300 Credited",
          "message" => get_payout_processed_message(rewards_lead),
          "client_uuid" => rewards_lead.id
        }

      "rejected_by_manager" ->
        %{
          "title" => "Site Visit Rejected by Manager",
          "message" => "Your manager has rejected site visit request for your client #{rewards_lead.name}",
          "client_uuid" => rewards_lead.id
        }

      "pending" ->
        %{
          "title" => "Site Visit Sent for Approval",
          "message" => "Site visit request for your client #{rewards_lead.name} has been sent to developer for approval",
          "client_uuid" => rewards_lead.id
        }

      _ ->
        nil
    end
  end

  defp get_sv_rejected_message(rewards_lead) do
    "Developer has rejected site visit request for your client #{rewards_lead.name}"
  end

  defp get_payout_processed_message(rewards_lead) do
    "Site Visit of your client #{rewards_lead.name} is approved"
  end

  defp get_reward_approved_message(rewards_lead) do
    "Developer has approved site visit request for your client #{rewards_lead.name}"
  end
end
