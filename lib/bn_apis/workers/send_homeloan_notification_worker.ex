defmodule BnApis.SendHomeloanNotificationWorker do
  alias BnApis.Helpers.FcmNotification
  alias BnApis.Accounts.Credential
  alias BnApis.Homeloan.LeadStatus
  alias BnApis.Homeloan.Lead
  alias BnApis.Repo
  alias BnApis.Homeloan.LoanDisbursement

  def perform(id) do
    homeloan_lead = Repo.get_by(Lead, id: id)
    homeloan_lead = homeloan_lead |> Repo.preload(:latest_lead_status)

    lead_status_identifier =
      LeadStatus.get_details(homeloan_lead.latest_lead_status)[
        "status_identifier"
      ]

    credential = Credential.get_credential_from_broker_id(homeloan_lead.broker_id)

    type = "HOME_LOAN_UPDATE"

    notification_data = get_notification_data(homeloan_lead, lead_status_identifier)

    if not is_nil(notification_data) do
      FcmNotification.send_push(
        credential.fcm_id,
        %{data: notification_data, type: type},
        credential.id,
        credential.notification_platform
      )
    else
      nil
    end
  end

  def get_notification_data(homeloan_lead, lead_status_identifier) do
    case lead_status_identifier do
      "DOC_COLLECTION_IN_PROCESS" ->
        %{
          "title" => "Home Loan Update",
          "message" => "Document collection for home loan lead of #{homeloan_lead.name} is in process.",
          "client_uuid" => homeloan_lead.id
        }

      "DOC_COLLECTED" ->
        %{
          "title" => "Home Loan Update",
          "message" => "Documents collected for home loan lead of #{homeloan_lead.name}.",
          "client_uuid" => homeloan_lead.id
        }

      "PROCESSING_DOC_IN_BANKS" ->
        %{
          "title" => "Home Loan Update",
          "message" => "Home loan lead of #{homeloan_lead.name} is now with bank for processing documents.",
          "client_uuid" => homeloan_lead.id
        }

      "OFFER_RECEIVED_FROM_BANKS" ->
        %{
          "title" => "Home Loan Update",
          "message" => "Home loan lead of #{homeloan_lead.name} has received offer for loan from bank.",
          "client_uuid" => homeloan_lead.id
        }

      "FAILED" ->
        %{
          "title" => "Home Loan Update",
          "message" => "We could not fulfil loan requirement for home loan lead of #{homeloan_lead.name}.",
          "client_uuid" => homeloan_lead.id
        }

      "CLIENT_APPROVAL_RECEIVED" ->
        %{
          "title" => "Home Loan Update",
          "message" => "#{homeloan_lead.name} has accepted the loan request.",
          "client_uuid" => homeloan_lead.id
        }

      "COMMUNICATION_WITH_CLIENT" ->
        %{
          "title" => "Home Loan Update",
          "message" => "We are in communication with client to process home loan lead of #{homeloan_lead.name}.",
          "client_uuid" => homeloan_lead.id
        }

      "RESIDENCE_VERIFICATION" ->
        %{
          "title" => "Home Loan Update",
          "message" => "Home loan lead of #{homeloan_lead.name} has moved to residence verification stage.",
          "client_uuid" => homeloan_lead.id
        }

      "OFFICE_VERIFICATION" ->
        %{
          "title" => "Home Loan Update",
          "message" => "Home loan lead of #{homeloan_lead.name} has moved to office verification stage.",
          "client_uuid" => homeloan_lead.id
        }

      "CREDIT_APPROVED" ->
        %{
          "title" => "Home Loan Update",
          "message" => "Credit has been approved for home loan lead of #{homeloan_lead.name}.",
          "client_uuid" => homeloan_lead.id
        }

      "AFTER_SUBMISSION_REQUIREMENTS" ->
        %{
          "title" => "Home Loan Update",
          "message" => "Home loan lead of #{homeloan_lead.name} has moved to after submission requirements stage.",
          "client_uuid" => homeloan_lead.id
        }

      "SANCTION_LETTER_ISSUED" ->
        %{
          "title" => "Home Loan Update",
          "message" => "Sanction letter has been issues for home loan lead of #{homeloan_lead.name}.",
          "client_uuid" => homeloan_lead.id
        }

      "ORIGINAL_AGREEMENT" ->
        %{
          "title" => "Home Loan Update",
          "message" => "Home loan lead of #{homeloan_lead.name} has moved to original agreement stage.",
          "client_uuid" => homeloan_lead.id
        }

      "VALUATION_TO_PROCESS" ->
        %{
          "title" => "Home Loan Update",
          "message" => "Valuation has started for home loan lead of #{homeloan_lead.name}.",
          "client_uuid" => homeloan_lead.id
        }

      "BANK_DOCKET_DULY_SIGNED_AND_COLLECTED" ->
        %{
          "title" => "Home Loan Update",
          "message" => "Bank docket has been duly signed and collected for Home loan lead of #{homeloan_lead.name}.",
          "client_uuid" => homeloan_lead.id
        }

      "SUBMISSION_FOR_DISBURSEMENT" ->
        %{
          "title" => "Home Loan Update",
          "message" => "Home loan lead of #{homeloan_lead.name} has been submitted for disbursement.",
          "client_uuid" => homeloan_lead.id
        }

      "DISBURSED_WITH_CHEQUE_RTGS" ->
        %{
          "title" => "Home Loan Update",
          "message" => "Home Loan has been disbursed via cheque / rtgs to your client #{homeloan_lead.name} successfully. You will get your commission soon",
          "client_uuid" => homeloan_lead.id
        }

      "HOME_LOAN_DISBURSED" ->
        %{
          "title" => "Home Loan Update",
          "message" => get_disbursed_message(homeloan_lead),
          "client_uuid" => homeloan_lead.id
        }

      "COMMISSION_RECEIVED" ->
        %{
          "title" => "Home Loan Update",
          "message" => get_commision_received_message(homeloan_lead),
          "client_uuid" => homeloan_lead.id
        }

      _ ->
        nil
    end
  end

  def get_client_approval_message(homeloan_lead) do
    "#{homeloan_lead.name} has accepted the loan request"
  end

  def get_disbursed_message(homeloan_lead) do
    amount = LeadStatus.get_amount_in_text(homeloan_lead.latest_lead_status.amount)
    amount = if is_nil(amount), do: LoanDisbursement.get_latest_disbursement_amount_of_lead(homeloan_lead), else: amount

    name = homeloan_lead.name

    "Home Loan of #{amount} has been disbursed to your client #{name} Successfully. You will get your commission soon"
  end

  def get_commision_received_message(homeloan_lead) do
    amount = LeadStatus.get_amount_in_text(homeloan_lead.latest_lead_status.amount)
    amount = if is_nil(amount), do: LoanDisbursement.get_latest_commission_amount_of_lead(homeloan_lead), else: amount

    "Congratulation, Rs. #{amount} commission has been credited in your bank account for loan disbursed to your client #{homeloan_lead.name}"
  end
end
