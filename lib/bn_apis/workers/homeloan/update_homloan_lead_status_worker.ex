defmodule BnApis.Homeloan.UpdateHomeloanLeadStatusWorker do
  import Ecto.Query
  alias BnApis.Homeloan.LeadStatus
  alias BnApis.Homeloan.Lead
  alias BnApis.Homeloan.Status
  alias BnApis.Repo
  alias BnApis.Helpers.FcmNotification
  alias BnApis.Accounts.Credential

  @threshold_days 7

  def perform() do
    mark_expired_leads_as_failed()
    notify_brokers_for_failing_leads()
  end

  defp mark_expired_leads_as_failed() do
    client_approval_pending_status_id = Status.get_status_id_from_identifier("CLIENT_APPROVAL_PENDING")

    failed_status_id = Status.get_status_id_from_identifier("FAILED")
    threshold_days_ago = Timex.now() |> Timex.shift(days: -1 * @threshold_days)

    Repo.all(
      from(l in Lead,
        join: ls in LeadStatus,
        on: l.latest_lead_status_id == ls.id,
        where:
          ls.status_id == ^client_approval_pending_status_id and
            ls.inserted_at < ^threshold_days_ago
      )
    )
    |> Enum.each(fn lead ->
      LeadStatus.create_lead_status!(lead, failed_status_id, nil, nil, nil, nil)
    end)
  end

  defp notify_brokers_for_failing_leads() do
    client_approval_pending_status_id = Status.get_status_id_from_identifier("CLIENT_APPROVAL_PENDING")

    threshold_days_ago = Timex.now() |> Timex.shift(days: -1 * (@threshold_days - 1))

    Repo.all(
      from(l in Lead,
        join: ls in LeadStatus,
        on: l.latest_lead_status_id == ls.id,
        where:
          ls.status_id == ^client_approval_pending_status_id and
            ls.inserted_at < ^threshold_days_ago
      )
    )
    |> Enum.each(fn lead ->
      send_failing_lead_notification_to_broker(lead)
    end)
  end

  defp send_failing_lead_notification_to_broker(lead) do
    type = "HOME_LOAN_UPDATE"
    credential = Credential.get_credential_from_broker_id(lead.broker_id)

    notification_data = %{
      "title" => "Home Loan Update",
      "message" => "Your client #{lead.name} has not given consent yet, kindly check.",
      "client_uuid" => lead.id
    }

    FcmNotification.send_push(
      credential.fcm_id,
      %{data: notification_data, type: type},
      credential.id,
      credential.notification_platform
    )
  end
end
