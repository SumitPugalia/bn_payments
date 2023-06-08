defmodule BnApis.Homeloan.DocType do
  @pan %{id: 1, name: "PAN"}
  @aadhar %{id: 2, name: "Aadhar"}
  @photo %{id: 3, name: "Photo"}
  @salary_slip %{id: 4, name: "Salary Slips (3 Months)"}
  @bank_statement %{id: 5, name: "Bank Statement (6 Months)"}
  @form_16 %{id: 6, name: "Form16 (Last 2 yr)"}
  @appointment_letter %{id: 7, name: "Appointment/Increment Letter"}
  @rent_agreement %{id: 8, name: "Rent Agreement/Electricity bill"}
  @qualification_degree %{id: 9, name: "Qualification Degree"}
  @existing_loan %{id: 10, name: "Existing loan(bank statement) "}
  @company_id_card %{id: 11, name: "Company ID Card"}
  @as_26 %{id: 12, name: "26AS (Last 2 yr)"}
  @itr %{id: 13, name: "ITR (Last 3 yr)"}
  @financial %{id: 14, name: "Financial (Last 3 yr)"}
  @account_statement %{id: 15, name: "Current Account Statement (1 yr)"}
  @company_kyc %{id: 16, name: "Company KYC"}
  @gst %{id: 17, name: "GST Certificate"}
  @office_address %{id: 18, name: "Office Address proof & Electricity Bill"}
  @gomasta %{id: 19, name: "Gomasta/GST/VAT (Last 3 yr)"}
  @company_itr %{id: 20, name: "ITR:Company (Last 3 yr)"}
  @as_26_self_emp %{id: 21, name: "26AS (Last 3 yr)"}
  @gst_return %{id: 22, name: "GST Return/ GST 3B (Last 1 yr)"}
  @bank_statement_overseas %{id: 23, name: "Bank Statement: Indian & Overseas (Last 1 yr)"}
  @salary_slip_nri %{id: 24, name: "Salary Slips (Last 1 yr)"}
  @appointment_letter_nri %{id: 25, name: "Appointment letter / Contract Copy"}
  @employment_proof_nri %{id: 26, name: "Employment proof (Last 3 yr)"}
  @passport_visa %{id: 27, name: "Passport & Visa (All pages)"}
  @residence_proof_nri %{id: 28, name: "Residence Proof (India & Abroad)"}
  @cdc_copy %{id: 29, name: "CDC copy (If Shippy)"}
  @power_of_attorney %{id: 30, name: "Power of Attorney"}
  @others %{id: 31, name: "Others"}

  defp all_docs() do
    [
      @pan,
      @aadhar,
      @photo,
      @salary_slip,
      @bank_statement,
      @form_16,
      @appointment_letter,
      @rent_agreement,
      @qualification_degree,
      @existing_loan,
      @company_id_card,
      @as_26,
      @itr,
      @financial,
      @account_statement,
      @company_kyc,
      @gst,
      @office_address,
      @gomasta,
      @company_itr,
      @as_26_self_emp,
      @gst_return,
      @bank_statement_overseas,
      @salary_slip_nri,
      @appointment_letter_nri,
      @employment_proof_nri,
      @passport_visa,
      @residence_proof_nri,
      @cdc_copy,
      @power_of_attorney,
      @others
    ]
  end

  defp salaried_doc_list() do
    [
      @pan,
      @aadhar,
      @photo,
      @salary_slip,
      @bank_statement,
      @form_16,
      @appointment_letter,
      @rent_agreement,
      @qualification_degree,
      @existing_loan,
      @company_id_card,
      @as_26,
      @others
    ]
  end

  defp self_employed_doc_list() do
    [
      @pan,
      @aadhar,
      @photo,
      @rent_agreement,
      @itr,
      @financial,
      @as_26_self_emp,
      @account_statement,
      @bank_statement,
      @company_kyc,
      @gst,
      @office_address,
      @gomasta,
      @company_itr,
      @as_26_self_emp,
      @gst_return,
      @existing_loan,
      @others
    ]
  end

  defp nri_doc_list() do
    [
      @pan,
      @aadhar,
      @photo,
      @bank_statement_overseas,
      @salary_slip_nri,
      @appointment_letter_nri,
      @employment_proof_nri,
      @passport_visa,
      @residence_proof_nri,
      @qualification_degree,
      @cdc_copy,
      @power_of_attorney,
      @company_id_card,
      @others
    ]
  end

  defp unemployed_doc_list do
    self_employed_doc_list()
  end

  def get_details_by_id(id) do
    all_docs() |> Enum.find(&(Map.get(&1, :id) == id))
  end

  def get_doc_types(employment_type) do
    case employment_type do
      1 -> {:ok, salaried_doc_list()}
      2 -> {:ok, self_employed_doc_list()}
      3 -> {:ok, nri_doc_list()}
      4 -> {:ok, unemployed_doc_list()}
      _ -> {:error, "employment type doesnt exist"}
    end
  end
end
