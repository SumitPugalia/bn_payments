defmodule BnApis.Homeloan.Status do
  alias BnApis.Helpers.S3Helper

  @status_list %{
    1 => %{
      "identifier" => "CLIENT_APPROVAL_PENDING",
      "display_name" => "Client Approval Pending",
      "text" => "Client's approval pending",
      "order_for_employee_panel" => 1,
      "bg_color_code" => "#EEEEEE",
      "text_color_code" => "#595959",
      "active" => true
    },
    2 => %{
      "identifier" => "DOC_COLLECTION_IN_PROCESS",
      "display_name" => "Document Collection In Process",
      "text" => "Document collection in process",
      "order_for_employee_panel" => 4,
      "bg_color_code" => "#FFF5E5",
      "text_color_code" => "#FF9601",
      "active" => true
    },
    3 => %{
      "identifier" => "DOC_COLLECTED",
      "display_name" => "Documents Collected",
      "text" => "Documents collected",
      "order_for_employee_panel" => 5,
      "bg_color_code" => "#FFF5E5",
      "text_color_code" => "#FF9601",
      "active" => true
    },
    4 => %{
      "identifier" => "PROCESSING_DOC_IN_BANKS",
      "display_name" => "Processing Documents In Banks",
      "text" => "Processing documents in <banks>",
      "order_for_employee_panel" => 6,
      "bg_color_code" => "#FFF5E5",
      "text_color_code" => "#FF9601",
      "active" => true
    },
    5 => %{
      "identifier" => "OFFER_RECEIVED_FROM_BANKS",
      "display_name" => "Offer Received From Banks",
      "text" => "Offer received from <banks>",
      "order_for_employee_panel" => 10,
      "bg_color_code" => "#FFF5E5",
      "text_color_code" => "#FF9601",
      "active" => true
    },
    6 => %{
      "identifier" => "HOME_LOAN_DISBURSED",
      "display_name" => "Loan Disbursed",
      "text" => "₹<amount> of loan disbursed",
      "order_for_employee_panel" => 18,
      "bg_color_code" => "#E5F7EF",
      "text_color_code" => "#26B972",
      "active" => true
    },
    7 => %{
      "identifier" => "COMMISSION_RECEIVED",
      "display_name" => "Commission Received",
      "text" => "₹<amount> commission received",
      "order_for_employee_panel" => 19,
      "bg_color_code" => "#FFF5E5",
      "text_color_code" => "#FF9601",
      "active" => true
    },
    8 => %{
      "identifier" => "FAILED",
      "display_name" => "Failed",
      "text" => "Failed",
      "order_for_employee_panel" => 20,
      "bg_color_code" => "#FDEEEE",
      "text_color_code" => "#EE5454",
      "active" => true
    },
    9 => %{
      "identifier" => "CLIENT_APPROVAL_RECEIVED",
      "display_name" => "Client Approval Received",
      "text" => "Client approval received",
      "order_for_employee_panel" => 2,
      "bg_color_code" => "#FFF5E5",
      "text_color_code" => "#FF9601",
      "active" => true
    },
    10 => %{
      "identifier" => "COMMUNICATION_WITH_CLIENT",
      "display_name" => "Communication with Client",
      "text" => "Communication with Client",
      "order_for_employee_panel" => 3,
      "bg_color_code" => "#FFF5E5",
      "text_color_code" => "#FF9601",
      "active" => true
    },
    11 => %{
      "identifier" => "RESIDENCE_VERIFICATION",
      "display_name" => "Residence Verification",
      "text" => "Residence Verification",
      "order_for_employee_panel" => 7,
      "bg_color_code" => "#FFF5E5",
      "text_color_code" => "#FF9601",
      "active" => false
    },
    12 => %{
      "identifier" => "OFFICE_VERIFICATION",
      "display_name" => "Office Verification",
      "text" => "Office Verification",
      "order_for_employee_panel" => 8,
      "bg_color_code" => "#FFF5E5",
      "text_color_code" => "#FF9601",
      "active" => false
    },
    13 => %{
      "identifier" => "CREDIT_APPROVED",
      "display_name" => "Credit Approved",
      "text" => "Credit Approved",
      "order_for_employee_panel" => 9,
      "bg_color_code" => "#FFF5E5",
      "text_color_code" => "#FF9601",
      "active" => false
    },
    14 => %{
      "identifier" => "AFTER_SUBMISSION_REQUIREMENTS",
      "display_name" => "After Submission if any requirements",
      "text" => "After Submission if any requirements",
      "order_for_employee_panel" => 11,
      "bg_color_code" => "#FFF5E5",
      "text_color_code" => "#FF9601",
      "active" => false
    },
    15 => %{
      "identifier" => "SANCTION_LETTER_ISSUED",
      "display_name" => "Sanction Letter Issued",
      "text" => "Sanction Letter Issued",
      "order_for_employee_panel" => 12,
      "bg_color_code" => "#E5F7EF",
      "text_color_code" => "#0DAF60",
      "active" => true
    },
    16 => %{
      "identifier" => "ORIGINAL_AGREEMENT",
      "display_name" => "Original Agreement",
      "text" => "Original Agreement",
      "order_for_employee_panel" => 13,
      "bg_color_code" => "#FFF5E5",
      "text_color_code" => "#FF9601",
      "active" => true
    },
    17 => %{
      "identifier" => "VALUATION_TO_PROCESS",
      "display_name" => "Valuation to process",
      "text" => "Valuation to process",
      "order_for_employee_panel" => 14,
      "bg_color_code" => "#FFF5E5",
      "text_color_code" => "#FF9601",
      "active" => false
    },
    18 => %{
      "identifier" => "BANK_DOCKET_DULY_SIGNED_AND_COLLECTED",
      "display_name" => "Bank Docket Duly Signed and Collected",
      "text" => "Bank Docket Duly Signed and Collected",
      "order_for_employee_panel" => 15,
      "bg_color_code" => "#FFF5E5",
      "text_color_code" => "#FF9601",
      "active" => true
    },
    19 => %{
      "identifier" => "SUBMISSION_FOR_DISBURSEMENT",
      "display_name" => "Submission for Disbursement",
      "text" => "Submission for Disbursement",
      "order_for_employee_panel" => 16,
      "bg_color_code" => "#FFF5E5",
      "text_color_code" => "#FF9601",
      "active" => true
    },
    20 => %{
      "identifier" => "DISBURSED_WITH_CHEQUE_RTGS",
      "display_name" => "Disbursed with Cheque/RTGS",
      "text" => "Disbursed with Cheque/RTGS",
      "order_for_employee_panel" => 17,
      "bg_color_code" => "#FFF5E5",
      "text_color_code" => "#FF9601",
      "active" => false
    }
  }

  @dsa_dashboard_status_ids [9, 4, 15, 6, 8]

  @status_identifier_id_mapping Enum.reduce(
                                  @status_list,
                                  %{},
                                  &Map.put(
                                    &2,
                                    Map.get(elem(&1, 1), "identifier"),
                                    elem(&1, 0)
                                  )
                                )

  def get_status_id_from_identifier(status_identifier) do
    @status_identifier_id_mapping[status_identifier]
  end

  def get_status_logo_from_identifier(status_identifier) do
    case status_identifier do
      "PROCESSING_DOC_IN_BANKS" -> S3Helper.get_imgix_url("assets/processing_doc_in_banks.png")
      "SANCTION_LETTER_ISSUED" -> S3Helper.get_imgix_url("assets/sanction_letter_issued.png")
      "HOME_LOAN_DISBURSED" -> S3Helper.get_imgix_url("assets/homeloan_disbursed.png")
      "FAILED" -> S3Helper.get_imgix_url("assets/failed.png")
      "CLIENT_APPROVAL_RECEIVED" -> S3Helper.get_imgix_url("assets/client_approval_recieved.png")
      "CLIENT_APPROVAL_PENDING" -> S3Helper.get_imgix_url("assets/client_approval_pending.png")
      "DOC_COLLECTION_IN_PROCESS" -> S3Helper.get_imgix_url("assets/doc_collection_in_process.png")
      "DOC_COLLECTED" -> S3Helper.get_imgix_url("assets/doc_collected.png")
      "OFFER_RECEIVED_FROM_BANKS" -> S3Helper.get_imgix_url("assets/offer_received.png")
      "COMMISSION_RECEIVED" -> S3Helper.get_imgix_url("assets/commission_received.png")
      "COMMUNICATION_WITH_CLIENT" -> S3Helper.get_imgix_url("assets/communication_with_client.png")
      "ORIGINAL_AGREEMENT" -> S3Helper.get_imgix_url("assets/original_agreement.png")
      "BANK_DOCKET_DULY_SIGNED_AND_COLLECTED" -> S3Helper.get_imgix_url("assets/bank_docket_duly_and_collected.png")
      "SUBMISSION_FOR_DISBURSEMENT" -> S3Helper.get_imgix_url("assets/submission_for_disbursement.png")
      "DISBURSED_WITH_CHEQUE_RTGS" -> S3Helper.get_imgix_url("assets/disbursed_with_cheque_rtgs.png")
      _ -> S3Helper.get_imgix_url("assets/offer_received.png")
    end
  end

  def status_list() do
    @status_list
  end

  def get_status_from_id(id) do
    @status_list[id]
  end

  def dsa_dashboard_status_ids() do
    @dsa_dashboard_status_ids
  end

  # array of status used in team dashboard
  def dsa_dashboard_status_list() do
    dsa_status_ids = dsa_dashboard_status_ids()

    Enum.reduce(dsa_status_ids, [], fn id, acc ->
      acc ++ [@status_list[id]]
    end)
  end

  # array of status used in panel and map
  def dsa_status_list() do
    [
      # @status_list[9],
      @status_list[4],
      @status_list[15],
      @status_list[6],
      @status_list[8]
    ]
  end

  # map of status list used in filtering
  def status_list_for_dsa() do
    Enum.filter(status_list(), fn {status_id, _data} ->
      status_id in [9, 4, 15, 6, 8]
    end)
  end

  def lead_status_filters_list() do
    [
      %{
        "identifier" => "CLIENT_APPROVAL_RECEIVED",
        "display_name" => "Client Approval Received"
      },
      %{
        "identifier" => "PROCESSING_DOC_IN_BANKS",
        "display_name" => "Processing Documents In Banks"
      },
      %{
        "identifier" => "SANCTION_LETTER_ISSUED",
        "display_name" => "Sanction Letter Issued"
      },
      %{
        "identifier" => "HOME_LOAN_DISBURSED",
        "display_name" => "Loan Disbursed"
      },
      %{
        "identifier" => "FAILED",
        "display_name" => "Failed"
      },
      %{
        "identifier" => "invoice_approval_pending",
        "display_name" => "Invoice Approval Pending"
      },
      %{
        "identifier" => "paid",
        "display_name" => "Paid"
      }
    ]
  end
end
