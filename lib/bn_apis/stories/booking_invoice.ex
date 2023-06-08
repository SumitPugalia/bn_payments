defmodule BnApis.Stories.BookingInvoice do
  use Ecto.Schema

  alias BnApis.Repo
  alias BnApis.Helpers.AuditedRepo
  alias BnApis.Stories.Schema.BookingInvoice
  alias BnApis.Stories.{Invoice, InvoiceItem}
  alias BnApis.Helpers.{Utils, InvoiceHelper, ApplicationHelper, S3Helper}
  alias BnApis.Invoices.InvoiceNumber
  alias BnApis.Stories.Schema.Invoice, as: InvoiceSchema

  @default_booking_invoice_amount 5000
  @piramal_booking_invoice_amount 10000
  @booking_invoice_amount_via_booking_reward_flow 10000
  @cgst 0.09
  @sgst 0.09
  @tds 0.05
  @mumbai_city_id 1
  ## Booking Invoice Type
  @booking_invoice_type "IV_BI"
  @booking_reward_invoice_type "IV_BR"
  @invoice_type_reward InvoiceSchema.type_reward()
  @imgix_domain ApplicationHelper.get_imgix_domain()

  def create_or_update_booking_invoice_record(
        params = %{
          "has_gst" => _has_gst,
          "invoice_amount" => _invoice_amount,
          "invoice_id" => invoice_id
        },
        user_map
      ) do
    case get_booking_invoice_by_invoice_id(invoice_id) do
      nil ->
        add_booking_invoice(params, user_map)

      booking_invoice ->
        update_booking_invoice(params, booking_invoice, user_map)
    end
  end

  def create_or_update_booking_invoice_record(_params, _user_map), do: {:error, "Invalid params for booking invoice."}

  def create_booking_invoice_pdf(nil, _user_map), do: {:error, "Invalid params for generating a booking invoice pdf."}

  def create_booking_invoice_pdf(invoice_uuid, user_map) do
    invoice = Invoice.get_invoice_by_uuid(invoice_uuid)

    cond do
      is_nil(invoice) ->
        {:error, "Corresponding Advanced Brokerage Invoice does not exist."}

      invoice.type == @invoice_type_reward ->
        {:error, "Cannot create booking invoice for reward type invoice"}

      true ->
        booking_invoice_amount = booking_invoice_amount(invoice)

        Repo.transaction(fn ->
          %{
            "has_gst" => not is_nil(invoice.billing_company.gst),
            "invoice_amount" => booking_invoice_amount,
            "invoice_id" => invoice.id
          }
          |> create_or_update_booking_invoice_record(user_map)
          |> case do
            {:ok, booking_invoice} ->
              generate_booking_invoice_pdf(booking_invoice, invoice, user_map)

            {:error, error} ->
              Repo.rollback(error)
          end
        end)
    end
  end

  def get_booking_invoice_by_invoice_id(invoice_id), do: Repo.get_by(BookingInvoice, invoice_id: invoice_id)

  def create_booking_invoice_pdf_params(invoice, has_gst?, total_invoice_amount, invoice_id) do
    invoice_date = DateTime.from_unix!(invoice.invoice_date) |> Timex.Timezone.convert("Asia/Kolkata") |> DateTime.to_date()

    invoice_type = if invoice.type == @invoice_type_reward, do: @booking_reward_invoice_type, else: @booking_invoice_type

    booking_invoice_number =
      InvoiceNumber.find_or_create_invoice_number(
        %{
          invoice_type: invoice_type,
          invoice_reference_id: invoice_id,
          city_id: @mumbai_city_id
        },
        invoice.invoice_date
      )

    multiplier = get_multiplier_for_total_invoice_amount(has_gst?)
    total_invoice_amount_in_words = Utils.float_in_words(total_invoice_amount * multiplier) <> " Rupees"

    Map.merge(invoice, %{
      booking_invoice_number: booking_invoice_number.invoice_number,
      invoice_date: invoice_date,
      total_invoice_amount: total_invoice_amount,
      total_invoice_amount_in_words: total_invoice_amount_in_words
    })
  end

  ## Private APIs
  defp generate_booking_invoice_pdf(booking_invoice, invoice, user_map) do
    invoice_items = InvoiceItem.get_active_invoice_items_records(invoice.id)
    invoice = Map.put(invoice, :invoice_items, invoice_items)

    invoice =
      create_booking_invoice_pdf_params(
        invoice,
        booking_invoice.has_gst,
        booking_invoice.invoice_amount,
        booking_invoice.id
      )

    prefix = "booking_invoices"
    path = InvoiceHelper.get_path_for_booking_invoice(invoice, booking_invoice.has_gst)
    s3_pdf_path = InvoiceHelper.upload_invoice(prefix, path, booking_invoice.id)

    InvoiceHelper.get_pdf_url(s3_pdf_path)
    |> case do
      nil ->
        {:error, "Something went wrong file generating invoice PDF."}

      imgx_pdf_url ->
        update_booking_invoice_pdf_url(booking_invoice, imgx_pdf_url, user_map)
    end
  end

  defp get_multiplier_for_total_invoice_amount(true), do: 1 + @cgst + @sgst - @tds
  defp get_multiplier_for_total_invoice_amount(false), do: 1 - @tds

  defp update_booking_invoice_pdf_url(booking_invoice, imgx_pdf_url, user_map) do
    old_booking_invoice_url = booking_invoice.booking_invoice_pdf_url

    booking_invoice
    |> BookingInvoice.changeset(%{booking_invoice_pdf_url: imgx_pdf_url})
    |> AuditedRepo.update(user_map)
    |> case do
      {:ok, _changeset} ->
        Task.async(fn -> delete_old_booking_invoice(old_booking_invoice_url) end)
        imgx_pdf_url

      {:error, error} ->
        {:error, error}
    end
  end

  defp delete_old_booking_invoice(nil), do: {:ok, ""}

  defp delete_old_booking_invoice(file_url) do
    s3_path = parse_file_url(String.contains?(file_url, @imgix_domain), file_url)
    if is_nil(s3_path), do: {:ok, ""}, else: S3Helper.delete_file(s3_path)
  end

  defp parse_file_url(false, _file_url), do: nil
  defp parse_file_url(true, file_url), do: String.replace(file_url, @imgix_domain <> "/", "")

  defp add_booking_invoice(
         params = %{
           "has_gst" => has_gst,
           "invoice_amount" => invoice_amount,
           "invoice_id" => invoice_id
         },
         user_map
       ) do
    booking_invoice_pdf_url = Map.get(params, "booking_invoice_pdf_url")

    %BookingInvoice{}
    |> BookingInvoice.changeset(%{
      has_gst: has_gst,
      invoice_amount: invoice_amount,
      invoice_id: invoice_id,
      booking_invoice_pdf_url: booking_invoice_pdf_url
    })
    |> AuditedRepo.insert(user_map)
    |> case do
      {:ok, booking_invoice} ->
        {:ok, booking_invoice}

      {:error, error} ->
        {:error, error}
    end
  end

  defp add_booking_invoice(_params, _user_map), do: {:error, "Invalid params for create a booking invoice."}

  defp update_booking_invoice(
         params = %{
           "has_gst" => has_gst,
           "invoice_amount" => invoice_amount,
           "invoice_id" => invoice_id
         },
         booking_invoice,
         user_map
       ) do
    booking_invoice_pdf_url = Map.get(params, "booking_invoice_pdf_url")

    booking_invoice
    |> BookingInvoice.changeset(%{
      has_gst: has_gst,
      invoice_amount: invoice_amount,
      invoice_id: invoice_id,
      booking_invoice_pdf_url: booking_invoice_pdf_url
    })
    |> AuditedRepo.update(user_map)
    |> case do
      {:ok, booking_invoice} ->
        {:ok, booking_invoice}

      {:error, error} ->
        {:error, error}
    end
  end

  defp update_booking_invoice(_params, _booking_invoice, _user_map),
    do: {:error, "Invalid params for update booking invoice."}

  defp booking_invoice_amount(%{is_created_by_piramal: true}), do: @piramal_booking_invoice_amount

  defp booking_invoice_amount(%{booking_rewards_lead_id: id}) when not is_nil(id),
    do: @booking_invoice_amount_via_booking_reward_flow

  defp booking_invoice_amount(_invoice), do: @default_booking_invoice_amount
end
