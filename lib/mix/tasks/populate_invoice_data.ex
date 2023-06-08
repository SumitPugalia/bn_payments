defmodule Mix.Tasks.PopulateInvoiceData do
  use Mix.Task
  import Ecto.Query

  alias BnApis.Repo
  alias BnApis.Helpers.Time
  alias BnApis.Accounts.{Credential, ProfileType}
  alias BnApis.Organizations.BillingCompany
  alias BnApis.Stories.{Invoice, BookingInvoice, LegalEntity}
  alias BnApisWeb.ChangesetView

  @path ["invoice_data.csv"]
  @default_booking_invoice_amount 5000

  @header ~w(id	status	user_id	brokerData_phone_number	brokerData_name	brokerData_fcm_id	companyId	projectId	invoice_id	project__rowNumber	project_project_id	project_rm_name	project_rm_number	project_rm_email	project_developer_name	project_project_name	project_ship_to_name	project_ship_to_address	project_legal_entity_name	project_locality	project_billing_address	project_gst	project_pan	project_place_of_supply	project_rera	project_crm_poc_name	project_crm_poc_number	project_crm_poc_email	project_finance_poc_name	project_finance_team_number	project_finance_team_email	project_brokerage_eligibility_terms	company__rowNumber	company_user_id	company_name	company_address	company_place_of_supply	company_company_type	company_email	company_gst	company_pan	company_rera	company_account_holder_name	company_ifsc	company_bank_account_type	company_account_number	company_confirm_account_number	company_signature	company_company_id	item_0_item_customer_name	item_0_item_unit_number	item_0_item_agreement_value	item_0_item_brokerage_percentage	item_0_item_brokerage_amount	item_0_id	item_1_item_customer_name	item_1_item_unit_number	item_1_item_agreement_value	item_1_item_brokerage_percentage	item_1_item_brokerage_amount	item_1_id	invoice_date	project_state_code	company_bank_name	item_2_item_customer_name	item_2_item_unit_number	item_2_item_agreement_value	item_2_item_brokerage_percentage	item_2_item_brokerage_amount	item_2_id	url	company_bill_to_state	company_bill_to_pincode	company_bill_to_city	five_k_invoice_url	user_phone_number	brokerData_test_user	brokerData_rera_id	brokerData_qr_code_url	project_status	project_sac	item_3_item_customer_name	item_3_item_unit_number	item_3_item_agreement_value	item_3_item_brokerage_amount	item_3_id	item_4_item_customer_name	item_4_item_unit_number	item_4_item_agreement_value	item_4_item_brokerage_amount	item_4_id	item_5_item_customer_name	item_5_item_unit_number	item_5_item_agreement_value	item_5_item_brokerage_amount	item_5_id	invoice_number	company_status	company_cancelled_cheque	item_0_item_building_name	item_0_item_wing_name	proofUrl	item_1_item_building_name	item_1_item_wing_name	item_2_item_building_name	item_2_item_wing_name	item_3_item_building_name	item_3_item_wing_name	item_4_item_building_name	item_4_item_wing_name	isAdvancePayment	utr_number	item_5_item_building_name	item_5_item_wing_name	invoice_changes)
  @shortdoc "Populate Invoice data to DB"
  def run(_) do
    Mix.Task.run("app.start", [])

    IO.puts("STARTING TO ADD INVOICE DATA")
    # remove first line from csv file that contains headers
    @path
    |> Enum.each(&populate/1)

    IO.puts("INVOICE DATA MIGRATION COMPLETED")
  end

  def populate(path) do
    File.stream!("#{File.cwd!()}/priv/data/#{path}")
    |> CSV.decode(strip_fields: true, headers: @header)
    |> Stream.map(&populate_invoice/1)
    |> Stream.filter(fn data -> not (data == :ok) end)
    |> CSV.encode(headers: @header ++ ["error"])
    |> Enum.into(File.stream!("failed_invoice_error.csv"))
  end

  defp fetch_data(data, id) do
    string = Enum.at(@header, id)
    data[string]
  end

  defp get_legal_entity_by_pan(nil), do: nil
  defp get_legal_entity_by_pan(""), do: nil

  defp get_legal_entity_by_pan(pan) do
    LegalEntity
    |> where([le], fragment("lower(?) = lower(?)", le.pan, ^pan))
    |> Repo.one()
  end

  defp get_legal_entity_by_gst(nil), do: nil
  defp get_legal_entity_by_gst(""), do: nil

  defp get_legal_entity_by_gst(gst) do
    valid_gst_length? = String.length(gst) == 15

    pan_from_gst =
      case valid_gst_length? do
        true -> String.slice(gst, 2, 10)
        false -> nil
      end

    get_legal_entity_by_pan(pan_from_gst)
  end

  defp get_billing_company(pan, account_number) when pan not in [nil, ""] and account_number not in [nil, ""] do
    BillingCompany
    |> join(:left, [bc], ba in assoc(bc, :bank_account))
    |> where([bc, ba], bc.pan == ^pan and ba.account_number == ^account_number)
    |> limit(1)
    |> Repo.one()
  end

  defp get_billing_company(_pan, _account_number), do: nil

  defp fetch_id(nil), do: nil
  defp fetch_id(entity), do: entity.id

  defp parse_amount(nil), do: 0
  defp parse_amount(""), do: 0

  defp parse_amount(amount) when is_binary(amount) do
    {amount, _decimal} = Integer.parse(amount)
    amount
  end

  defp parse_amount(amount), do: amount

  defp create_params(data) do
    broker_uuid = fetch_data(data, 2) |> String.trim()
    cred = Repo.get_by(Credential, uuid: broker_uuid, active: true)

    legal_entity_pan = fetch_data(data, 22) |> String.trim()
    legal_entity_gst = fetch_data(data, 21) |> String.trim()
    legal_entity = get_legal_entity_by_pan(legal_entity_pan)

    legal_entity_id = if is_nil(legal_entity), do: get_legal_entity_by_gst(legal_entity_gst) |> fetch_id(), else: fetch_id(legal_entity)

    billing_company_pan = fetch_data(data, 40) |> String.trim()
    billing_company_account_number = fetch_data(data, 45) |> String.trim()
    billing_company_id = get_billing_company(billing_company_pan, billing_company_account_number) |> fetch_id()

    invoice_items =
      Enum.reduce(0..5, [], fn i, acc ->
        customer_name = data["item_#{i}_item_customer_name"]
        unit_number = data["item_#{i}_item_unit_number"]
        agreement_value = data["item_#{i}_item_agreement_value"] |> parse_amount()
        brokerage_amount = data["item_#{i}_item_brokerage_amount"] |> parse_amount()
        wing_name = data["item_#{i}_item_wing_name"]
        building_name = data["item_#{i}_item_building_name"]

        invoice_item = %{
          "customer_name" => customer_name,
          "unit_number" => unit_number,
          "wing_name" => wing_name,
          "building_name" => building_name,
          "agreement_value" => agreement_value,
          "brokerage_amount" => brokerage_amount
        }

        if validate_invoice_item(invoice_item), do: acc ++ [invoice_item], else: acc
      end)

    {cred, legal_entity_id, billing_company_id, invoice_items}
  end

  defp validate_invoice_item(%{
         "customer_name" => customer_name,
         "unit_number" => unit_number,
         "wing_name" => wing_name,
         "building_name" => building_name,
         "agreement_value" => agreement_value,
         "brokerage_amount" => brokerage_amount
       }) do
    if valid_field(customer_name) and
         valid_field(unit_number) and
         valid_field(wing_name) and
         valid_field(building_name) and
         valid_field(agreement_value) and
         valid_field(brokerage_amount) do
      true
    else
      false
    end
  end

  defp valid_field(""), do: false
  defp valid_field(nil), do: false

  defp valid_field(value) do
    cond do
      is_binary(value) and String.trim(value) == "" -> false
      true -> true
    end
  end

  defp parse_invoice_status(status) when status == "preview", do: "draft"
  defp parse_invoice_status(status), do: status |> String.trim() |> String.downcase()

  defp parse_invoice_date(nil), do: NaiveDateTime.utc_now() |> Time.naive_to_epoch_in_sec()
  defp parse_invoice_date(""), do: NaiveDateTime.utc_now() |> Time.naive_to_epoch_in_sec()

  defp parse_invoice_date(date) do
    date
    |> Timex.parse("{YYYY}-{0M}-{D}")
    |> case do
      {:ok, date} -> date
      {:error, _error} -> NaiveDateTime.utc_now()
    end
    |> Time.naive_to_epoch_in_sec()
  end

  defp create_invoice_params(
         legal_entity_id,
         billing_company_id,
         invoice_status,
         invoice_date,
         invoice_number,
         invoice_proof_url,
         invoice_is_advance_payment,
         invoice_utr,
         invoice_change_notes,
         invoice_pdf_url,
         invoice_items
       ) do
    %{
      "status" => invoice_status,
      "invoice_number" => invoice_number,
      "invoice_date" => invoice_date,
      "legal_entity_id" => legal_entity_id,
      "billing_company_id" => billing_company_id,
      "proof_url" => invoice_proof_url,
      "is_advance_payment" => invoice_is_advance_payment,
      "payment_utr" => invoice_utr,
      "change_notes" => invoice_change_notes,
      "invoice_pdf_url" => invoice_pdf_url,
      "invoice_items" => invoice_items
    }
  end

  defp parse_invoice_number(nil, invoice_id), do: "#{invoice_id}"
  defp parse_invoice_number("", invoice_id), do: "#{invoice_id}"
  defp parse_invoice_number(invoice_number, _invoice_id), do: invoice_number

  defp parse_is_advance_payment(is_advance_payment) when is_advance_payment in [nil, ""], do: false
  defp parse_is_advance_payment(is_advance_payment) when is_advance_payment in [true, "true"], do: true
  defp parse_is_advance_payment(_), do: false

  defp add_booking_invoice(invoice, booking_invoice_pdf_url, user_map) do
    invoice_id = Map.get(invoice, "id")
    invoice_id = if is_binary(invoice_id), do: invoice_id |> String.to_integer(), else: invoice_id

    billing_company_map = Map.get(invoice, "billing_company")
    billing_company_gst = Map.get(billing_company_map, "gst")

    booking_invoice_params = %{
      "has_gst" => not is_nil(billing_company_gst),
      "invoice_amount" => @default_booking_invoice_amount,
      "invoice_id" => invoice_id,
      "booking_invoice_pdf_url" => booking_invoice_pdf_url
    }

    BookingInvoice.create_or_update_booking_invoice_record(booking_invoice_params, user_map)
  end

  defp is_unique_invoice_for_broker(_broker_id, nil), do: true
  defp is_unique_invoice_for_broker(_broker_id, ""), do: true

  defp is_unique_invoice_for_broker(broker_id, invoice_number) do
    BnApis.Stories.Schema.Invoice
    |> where([inv], inv.broker_id == ^broker_id and ilike(inv.invoice_number, ^invoice_number))
    |> Repo.all()
    |> case do
      [] -> true
      _ -> false
    end
  end

  def populate_invoice({:error, data}) do
    IO.inspect("Error: #{data}")
    Map.put(data, "error", "something wrong with data")
  end

  def populate_invoice({:ok, data}) do
    # Extract data from CSV
    file_id = fetch_data(data, 0)
    {cred, legal_entity_id, billing_company_id, invoice_items} = create_params(data)
    broker_id = if not is_nil(cred), do: cred.broker_id
    organization_id = if not is_nil(cred), do: cred.organization_id

    invoice_status = fetch_data(data, 1) |> parse_invoice_status()
    invoice_date = fetch_data(data, 61) |> String.trim() |> parse_invoice_date()
    invoice_id = fetch_data(data, 8) |> String.trim()
    invoice_number = fetch_data(data, 96) |> String.trim() |> parse_invoice_number(invoice_id)
    invoice_proof_url = fetch_data(data, 101) |> String.trim()

    invoice_is_advance_payment = fetch_data(data, 110) |> String.trim() |> String.downcase() |> parse_is_advance_payment()

    invoice_utr = fetch_data(data, 111) |> String.trim()
    invoice_change_notes = fetch_data(data, 114) |> String.trim()
    invoice_pdf_url = fetch_data(data, 70) |> String.trim()
    booking_invoice_pdf_url = fetch_data(data, 74) |> String.trim()

    invoice_params =
      create_invoice_params(
        legal_entity_id,
        billing_company_id,
        invoice_status,
        invoice_date,
        invoice_number,
        invoice_proof_url,
        invoice_is_advance_payment,
        invoice_utr,
        invoice_change_notes,
        invoice_pdf_url,
        invoice_items
      )

    broker_id_exists? = not is_nil(broker_id)
    legal_entity_exists? = not is_nil(legal_entity_id)
    billing_company_exists? = not is_nil(billing_company_id)

    case {broker_id_exists?, legal_entity_exists?, billing_company_exists?} do
      {false, _, _} ->
        IO.inspect("Active broker id does not exists for CSV Id: #{file_id}")
        Map.put(data, "error", "Active broker id does not exists for CSV Id: #{file_id}")

      {_, false, _} ->
        IO.inspect("Active legal entity does not exists for CSV Id: #{file_id}")
        Map.put(data, "error", "Active legal entity does not exists for CSV Id: #{file_id}")

      {_, _, false} ->
        IO.inspect("Active Billing Company does not exists for CSV Id: #{file_id}")
        Map.put(data, "error", "Active Billing Company does not exists for CSV Id: #{file_id}")

      {true, true, true} ->
        user_map = %{user_id: broker_id, user_type: ProfileType.broker().name}

        with true <- is_unique_invoice_for_broker(broker_id, invoice_number),
             {:ok, invoice} <- Invoice.create_invoice(invoice_params, broker_id, organization_id, user_map),
             {:ok, _booking_invoice} <- add_booking_invoice(invoice, booking_invoice_pdf_url, user_map) do
          IO.inspect("Record with CSV Id: #{file_id} and Invoice Number: #{invoice_number} added.")
          :ok
        else
          false ->
            IO.inspect("Duplicate Invoice: Invoice with same Broker Id: #{broker_id} and Invoice number: #{invoice_number} on CSV Id: #{file_id} exists")

            :ok

          ## Uncomment the below to log duplicate entries:
          # Map.put(data, "error", "Duplicate Invoice: Invoice with same Broker Id: #{broker_id} and Invoice number: #{invoice_number} for CSV Id: #{file_id} exists")

          {:error, changeset} ->
            IO.inspect("============== Error:  =============")
            IO.inspect("Issue while adding record for CSV Id: #{file_id} and Invoice Number: #{invoice_number}")
            IO.inspect(changeset.errors)
            Map.put(data, "error", inspect(ChangesetView.translate_errors(changeset)))
        end

      {_, _, _} ->
        IO.inspect("Invalid params for CSV Id #{file_id}")
        Map.put(data, "error", "Invalid params for CSV Id #{file_id}")
    end
  end
end
