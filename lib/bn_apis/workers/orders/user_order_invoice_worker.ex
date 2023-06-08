defmodule BnApis.Orders.UserOrderInvoiceWorker do
  alias BnApis.Repo
  alias BnApis.Accounts.Credential
  alias BnApis.Helpers.{Time, Utils, InvoiceHelper}
  alias BnApis.Orders.MatchPlusPackage
  alias BnApis.Invoices.InvoiceNumber
  alias BnApis.Packages.Invoice
  alias BnApis.Packages

  @date_format "%d-%b-%Y"

  def perform(order_id, notify_broker \\ false) do
    order = Packages.get_user_order_by(%{id: order_id}, [:broker, :user_packages, :payments, user_packages: :match_plus_package, payments: :invoice])

    if not is_nil(order) do
      try do
        {is_gst_invoice, captured_payment, data} = get_order_data(order)

        prefix = "user_order_invoices"
        path = InvoiceHelper.get_card_path(data, is_gst_invoice)
        s3_pdf_path = InvoiceHelper.upload_invoice(prefix, path, order.id)
        {:ok, invoice} = save_pdf_path(s3_pdf_path, captured_payment, is_gst_invoice)

        if notify_broker and not is_nil(invoice.invoice_url) do
          InvoiceHelper.send_notification(invoice.invoice_url, order.broker_id)
        end
      rescue
        err ->
          InvoiceHelper.send_on_slack("Failed to generate Invoice Url for order id - #{order.id} because of error - #{inspect(err)}")
      end
    end
  end

  def get_invoice_number(order, captured_payment) do
    city_id = order.broker.operating_city

    InvoiceNumber.find_or_create_invoice_number(
      %{
        city_id: city_id,
        invoice_reference_id: captured_payment.id,
        invoice_type: "US"
      },
      captured_payment.created_at
    )
  end

  def get_order_data(order) do
    captured_payment = order.payments |> Enum.find(fn payment -> payment.payment_status == :captured end)
    invoice_number = get_invoice_number(order, captured_payment)
    price = captured_payment.amount

    {price, price_in_words, taxable_value, cgst_value, sgst_value, total_tax, total_tax_in_words} = Utils.tax_breakup(price)

    number_of_months =
      if not is_nil(hd(order.user_packages).match_plus_package),
        do: floor(hd(order.user_packages).match_plus_package.validity_in_days / MatchPlusPackage.days_in_month()),
        else: 1

    subscription_period =
      if number_of_months == 1,
        do: "1 Month",
        else: "#{number_of_months} Months"

    credential = Credential.get_credential_from_broker_id(order.broker_id) |> Repo.preload(:organization)

    credential =
      if not is_nil(credential),
        do: credential,
        else: Credential.get_any_credential_from_broker_id(order.broker_id) |> Repo.preload(:organization)

    invoice = captured_payment.invoice || %{}

    data = %{
      invoice_number: invoice_number.invoice_number,
      invoice_date: Time.get_formatted_datetime(captured_payment.created_at, @date_format),
      broker_name: order.broker.name,
      broker_organization_name: credential.organization.name,
      broker_organization_address: credential.organization.firm_address,
      broker_gst_legal_name: Map.get(invoice, :gst_legal_name),
      broker_gst_address: Map.get(invoice, :gst_address),
      broker_gst: Map.get(invoice, :gst),
      broker_gst_pan: Map.get(invoice, :gst_pan),
      current_start: Time.get_formatted_datetime(hd(order.user_packages).current_start, @date_format),
      current_end: Time.get_formatted_datetime(hd(order.user_packages).current_end, @date_format),
      price: price,
      subscription_period: subscription_period,
      price_in_words: price_in_words,
      taxable_value: taxable_value,
      cgst_value: cgst_value,
      sgst_value: sgst_value,
      total_tax: total_tax,
      total_tax_in_words: total_tax_in_words
    }

    is_gst_invoice = not is_nil(Map.get(invoice, :gst))
    {is_gst_invoice, captured_payment, data}
  end

  def save_pdf_path(s3_pdf_path, captured_payment, is_gst_invoice) do
    pdf_url = s3_pdf_path |> InvoiceHelper.get_pdf_url()

    if is_nil(captured_payment.invoice) do
      %{"invoice_url" => pdf_url, "is_gst_invoice" => is_gst_invoice, "payment_id" => captured_payment.id}
      |> Invoice.changeset()
      |> Repo.insert()
    else
      captured_payment.invoice
      |> Invoice.update_changeset(%{"invoice_url" => pdf_url, "is_gst_invoice" => is_gst_invoice})
      |> Repo.update()
    end
  end
end
