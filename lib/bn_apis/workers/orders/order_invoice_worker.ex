defmodule BnApis.Orders.OrderInvoiceWorker do
  import Ecto.Query
  alias BnApis.Repo
  alias BnApis.Accounts.Credential
  alias BnApis.Helpers.{Time, Utils, InvoiceHelper}
  alias BnApis.Orders.{Order, MatchPlusPackage, OrderPayment}
  alias BnApis.Invoices.InvoiceNumber

  @date_format "%d-%b-%Y"

  def perform(order_id, notify_broker \\ false) do
    order =
      Order
      |> join(:inner, [o], op in OrderPayment, on: o.id == op.order_id)
      |> where([o, op], o.id == ^order_id)
      |> where([o, op], o.status == ^Order.paid_status())
      |> where([o, op], op.razorpay_payment_status == ^OrderPayment.captured_status())
      |> preload([:broker, :match_plus_package, :order_payments])
      |> order_by([o], desc: o.id)
      |> Repo.all()
      |> List.last()

    if not is_nil(order) do
      try do
        {is_gst_invoice, data} = get_order_data(order)
        prefix = "order_invoices"
        path = InvoiceHelper.get_card_path(data, is_gst_invoice)
        s3_pdf_path = InvoiceHelper.upload_invoice(prefix, path, order.id)
        order = save_pdf_path(s3_pdf_path, order, is_gst_invoice)

        if notify_broker and not is_nil(order.invoice_url) do
          InvoiceHelper.send_notification(order.invoice_url, order.broker_id)
        end
      rescue
        _ -> InvoiceHelper.send_on_slack("Failed to generate Order Invoice Url for order id - #{order.id}")
      end
    end
  end

  def get_invoice_number(order, captured_payment) do
    city_id = order.broker.operating_city

    InvoiceNumber.find_or_create_invoice_number(
      %{
        city_id: city_id,
        invoice_reference_id: order.id,
        invoice_type: "OS_OT"
      },
      captured_payment.created_at
    )
  end

  def get_order_data(order) do
    captured_payment = Order.get_captured_payment(order)
    invoice_number = get_invoice_number(order, captured_payment)
    price = order.amount / 100

    {price, price_in_words, taxable_value, cgst_value, sgst_value, total_tax, total_tax_in_words} = Utils.tax_breakup(price)

    number_of_months =
      if not is_nil(order.match_plus_package),
        do: floor(order.match_plus_package.validity_in_days / MatchPlusPackage.days_in_month()),
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

    data = %{
      invoice_number: invoice_number.invoice_number,
      invoice_date: Time.get_formatted_datetime(captured_payment.created_at, @date_format),
      broker_name: order.broker.name,
      broker_organization_name: credential.organization.name,
      broker_organization_address: credential.organization.firm_address,
      broker_gst_legal_name: order.gst_legal_name,
      broker_gst_address: order.gst_address,
      broker_gst: order.gst,
      broker_gst_pan: order.gst_pan,
      current_start: Time.get_formatted_datetime(order.current_start, @date_format),
      current_end: Time.get_formatted_datetime(order.current_end, @date_format),
      price: price,
      subscription_period: subscription_period,
      price_in_words: price_in_words,
      taxable_value: taxable_value,
      cgst_value: cgst_value,
      sgst_value: sgst_value,
      total_tax: total_tax,
      total_tax_in_words: total_tax_in_words
    }

    is_gst_invoice = not is_nil(order.gst)
    {is_gst_invoice, data}
  end

  def save_pdf_path(s3_pdf_path, order, is_gst_invoice) do
    pdf_url = s3_pdf_path |> InvoiceHelper.get_pdf_url()
    attrs = %{"invoice_url" => pdf_url, "is_gst_invoice" => is_gst_invoice}

    Order.get_order(order.id)
    |> Order.changeset(attrs)
    |> Repo.update!()
  end
end
