defmodule BnApis.Memberships.MembershipOrderInvoiceWorker do
  alias BnApis.Repo
  alias BnApis.Accounts.Credential
  alias BnApis.Helpers.{Time, Utils, InvoiceHelper}
  alias BnApis.Memberships.{Membership, MembershipOrder}
  alias BnApis.Invoices.InvoiceNumber

  @date_format "%d-%b-%Y"

  def perform(membership_order_id, notify_broker \\ false) do
    membership_order = Repo.get_by(MembershipOrder, id: membership_order_id, order_status: "SUCCESS")
    membership_order = membership_order |> Repo.preload(membership: [:broker])

    if not is_nil(membership_order) do
      try do
        {is_gst_invoice, data} = get_membership_order_data(membership_order)
        prefix = "membership_order_invoices"
        path = InvoiceHelper.get_card_path(data, is_gst_invoice)
        s3_pdf_path = InvoiceHelper.upload_invoice(prefix, path, membership_order.id)
        membership_order = save_pdf_path(s3_pdf_path, membership_order, is_gst_invoice)

        if notify_broker and not is_nil(membership_order.invoice_url) do
          InvoiceHelper.send_notification(membership_order.invoice_url, membership_order.membership.broker_id)
        end
      rescue
        _ ->
          InvoiceHelper.send_on_slack("Failed to generate Invoice Url for MembershipOrder id - #{membership_order.id}")
      end
    end
  end

  def get_invoice_number(membership_order) do
    city_id = membership_order.membership.broker.operating_city

    InvoiceNumber.find_or_create_invoice_number(
      %{
        city_id: city_id,
        invoice_reference_id: membership_order.id,
        invoice_type: "OS_AP"
      },
      membership_order.order_creation_date
    )
  end

  def get_membership_order_data(membership_order) do
    invoice_number = get_invoice_number(membership_order)
    {price, _} = Integer.parse(membership_order.order_amount)

    {price, price_in_words, taxable_value, cgst_value, sgst_value, total_tax, total_tax_in_words} = Utils.tax_breakup(price)

    current_start = membership_order.order_creation_date
    {:ok, current_start_datetime} = DateTime.from_unix(current_start)

    current_end =
      current_start_datetime
      |> Timex.Timezone.convert("Asia/Kolkata")
      |> Timex.end_of_day()
      |> Timex.shift(days: Membership.validity_in_days())
      |> DateTime.to_unix()

    credential = Credential.get_credential_from_broker_id(membership_order.membership.broker_id) |> Repo.preload(:organization)

    credential =
      if not is_nil(credential),
        do: credential,
        else: Credential.get_any_credential_from_broker_id(membership_order.membership.broker_id) |> Repo.preload(:organization)

    data = %{
      invoice_number: invoice_number.invoice_number,
      invoice_date: Time.get_formatted_datetime(membership_order.order_creation_date, @date_format),
      broker_name: membership_order.membership.broker.name,
      broker_organization_name: credential.organization.name,
      broker_organization_address: credential.organization.firm_address,
      broker_gst_legal_name: membership_order.gst_legal_name,
      broker_gst_address: membership_order.gst_address,
      broker_gst: membership_order.gst,
      broker_gst_pan: membership_order.gst_pan,
      current_start: Time.get_formatted_datetime(current_start, @date_format),
      current_end: Time.get_formatted_datetime(current_end, @date_format),
      price: price,
      subscription_period: "1 Month",
      price_in_words: price_in_words,
      taxable_value: taxable_value,
      cgst_value: cgst_value,
      sgst_value: sgst_value,
      total_tax: total_tax,
      total_tax_in_words: total_tax_in_words
    }

    is_gst_invoice = not is_nil(membership_order.gst)
    {is_gst_invoice, data}
  end

  def save_pdf_path(s3_pdf_path, membership_order, is_gst_invoice) do
    pdf_url = s3_pdf_path |> InvoiceHelper.get_pdf_url()
    attrs = %{"invoice_url" => pdf_url, "is_gst_invoice" => is_gst_invoice}

    MembershipOrder.get_membership_order(membership_order.id)
    |> MembershipOrder.changeset(attrs)
    |> Repo.update!()
  end
end
