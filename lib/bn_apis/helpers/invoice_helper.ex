defmodule BnApis.Helpers.InvoiceHelper do
  alias BnApis.Helpers.{S3Helper, ApplicationHelper, HtmlHelper}
  alias BnApis.Accounts.Credential
  alias BnApis.Helpers.FcmNotification
  alias BnApis.Helpers.Time

  @page_width "250.0"
  @page_height "297.0"

  def get_pdf_url(path) do
    path |> BnApis.Helpers.S3Helper.get_imgix_url()
  end

  def remove_temp_files(pdf_file_path) do
    File.rm(pdf_file_path)
    pdf_file_path |> String.replace(".pdf", ".html") |> File.rm()
  end

  def upload_invoice(prefix, file_path, id) do
    random_suffix = SecureRandom.urlsafe_base64(8)
    s3_path = "#{prefix}/#{id}/#{random_suffix}.pdf"
    s3_path = S3Helper.upload_file(s3_path, file_path)
    remove_temp_files(file_path)
    s3_path
  end

  def generate_card_html(data, is_gst_invoice) do
    template =
      if is_gst_invoice,
        do: "gst_invoice.html",
        else: "default.html"

    {:safe, html} = Phoenix.View.render(BnApisWeb.InvoiceView, template, invoice_data: data)
    html |> IO.iodata_to_binary()
  end

  def generate_advance_brokerage_invoice_html(data, gst_invoice?) do
    template = if gst_invoice?, do: "advanced_brokerage_invoice.html", else: "default_advanced_brokerage_invoice.html"
    {:safe, html} = Phoenix.View.render(BnApisWeb.InvoiceView, template, invoice_data: data)
    html |> IO.iodata_to_binary()
  end

  def generate_booking_invoice_html(data, gst_invoice?) do
    template = if gst_invoice?, do: "gst_booking_invoice.html", else: "default_booking_invoice.html"

    {:safe, html} = Phoenix.View.render(BnApisWeb.InvoiceView, template, invoice_data: data)
    html |> IO.iodata_to_binary()
  end

  def get_card_path(data, is_gst_invoice) do
    data
    |> html_size_config()
    |> generate_card_html(is_gst_invoice)
    |> HtmlHelper.generate_pdf_from_html(@page_width, @page_height)
  end

  def html_size_config(data) do
    page_width = @page_width
    page_height = @page_height
    page_rotation = "0"
    scale = get_scale(page_width |> String.to_float(), page_height |> String.to_float())
    div_top = get_dynamic_top(scale)

    data
    |> Map.merge(%{
      "div_top" => div_top,
      "scale" => scale,
      "page_rotation" => page_rotation,
      "page_height" => page_height,
      "page_width" => page_width
    })
  end

  def get_path_for_dsa_homeloan_invoice(data, gst_invoice?) do
    {:safe, html} = Phoenix.View.render(BnApisWeb.InvoiceView, "dsa_homeloan_invoice.html", invoice_data: html_size_config(data), gst: gst_invoice?)

    html
    |> IO.iodata_to_binary()
    |> HtmlHelper.generate_pdf_from_html(@page_width, @page_height)
  end

  def get_path_for_advance_brokerage_invoice(data, gst_invoice?) do
    data
    |> html_size_config()
    |> generate_advance_brokerage_invoice_html(gst_invoice?)
    |> HtmlHelper.generate_pdf_from_html(@page_width, @page_height)
  end

  def get_path_for_booking_invoice(booking_invoice, gst_invoice?) do
    booking_invoice
    |> html_size_config()
    |> generate_booking_invoice_html(gst_invoice?)
    |> HtmlHelper.generate_pdf_from_html(@page_width, @page_height)
  end

  def get_scale(page_width, page_height) do
    # 1 mm = 3.7795275591 pixel
    [page_width * 3.7795275591 / 500, page_height * 3.7795275591 / 1100] |> Enum.min()
  end

  ## in pixels
  def get_dynamic_top(scale) do
    100 * scale
  end

  def send_on_slack(text) do
    channel = ApplicationHelper.get_slack_channel()

    text
    |> ApplicationHelper.notify_on_slack(channel)
  end

  def send_notification(invoice_url, broker_id) do
    user = Credential.get_credential_from_broker_id(broker_id)

    payload = %{
      type: "TRANSACTION_HISTORY",
      data: %{
        invoice_url: invoice_url,
        title: "Your Invoice is ready!",
        message: "Click to view the invoice."
      }
    }

    FcmNotification.send_push(
      user.fcm_id,
      payload,
      user.id,
      user.notification_platform
    )
  end

  def create_map_for_tnc_pdf(inv, aadhar, email, amount) do
    date_format = "%d-%b-%Y"

    case Credential.get_credential_from_broker_id(inv.broker.id) do
      nil ->
        nil

      cred ->
        %{
          "inv_id" => inv.id,
          "name" => inv.broker.name,
          "pan" => inv.billing_company.pan,
          "aadhar" => aadhar,
          "address" => inv.billing_company.address,
          "email" => email,
          "phone_number" => cred.phone_number,
          "place" => inv.billing_company.bill_to_city,
          "amount" => amount,
          "legal_entity_name" => inv.legal_entity.legal_entity_name,
          "date" => Time.get_formatted_datetime(Timex.now() |> DateTime.to_unix(), date_format),
          "signature_url" => inv.billing_company.signature
        }
    end
  end

  def generate_signed_tnc_pdf(nil), do: {:error, "Active credential does not exist"}

  def generate_signed_tnc_pdf(pdf_map) do
    prefix = "invoice_signed_tnc"
    page_width = "250.0"
    page_height = "297.0"
    page_rotation = "0"
    scale = get_scale(page_width |> String.to_float(), page_height |> String.to_float())
    div_top = get_dynamic_top(scale)

    pdf_map
    |> Map.merge(%{
      "div_top" => div_top,
      "scale" => scale,
      "page_rotation" => page_rotation,
      "page_height" => page_height,
      "page_width" => page_width
    })
    |> generate_signed_tnc_html()
    |> HtmlHelper.generate_pdf_from_html(page_width, page_height)
    |> upload_pdf_on_s3(prefix, pdf_map["inv_id"])
    |> get_pdf_url()
    |> case do
      nil ->
        {:error, "Something went wrong file generating signed tnc PDF."}

      imgx_pdf_url ->
        {:ok, imgx_pdf_url}
    end
  end

  defp generate_signed_tnc_html(pdf_map) do
    {:safe, html} = Phoenix.View.render(BnApisWeb.InvoiceView, "invoice_signed_tnc.html", pdf_map: pdf_map)

    html |> IO.iodata_to_binary()
  end

  defp upload_pdf_on_s3(file_path, prefix, inv_id) do
    upload_invoice(prefix, file_path, inv_id)
  end
end
