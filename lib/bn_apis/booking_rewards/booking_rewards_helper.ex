defmodule BnApis.BookingRewards.BookingRewardsHelper do
  alias BnApis.Helpers.S3Helper
  alias BnApis.BookingRewards.Schema.BookingRewardsLead
  alias BnApis.Helpers.{InvoiceHelper, HtmlHelper}

  def create_map_for_pdf(booking_rewards_lead) do
    date =
      booking_rewards_lead.booking_date
      |> DateTime.from_unix!()
      |> DateTime.to_string()
      |> String.split(" ")
      |> List.first()

    %{
      "id" => booking_rewards_lead.id,
      "booking_date" => date,
      "booking_form_number" => booking_rewards_lead.booking_form_number,
      "unit_number" => booking_rewards_lead.unit_number,
      "project" => booking_rewards_lead.story.name,
      "building_name" => booking_rewards_lead.building_name,
      "wing" => booking_rewards_lead.wing,
      "rera_number" => booking_rewards_lead.rera_number,
      "rera_carpet_area" => booking_rewards_lead.rera_carpet_area,
      "agreement_value" => booking_rewards_lead.agreement_value,
      "agreement_proof" => S3Helper.get_imgix_url(booking_rewards_lead.agreement_proof),
      "booking_client" => %{
        "name" => booking_rewards_lead.booking_client.name
      },
      "booking_payment" => %{
        "token_amount" => booking_rewards_lead.booking_payment.token_amount
      },
      "broker" => %{
        "name" => booking_rewards_lead.broker.name
      }
    }
  end

  def generate_booking_reward_pdf(booking_rewards_lead_map, booking_rewards_lead, user_map) do
    prefix = "booking_reward"
    page_width = "250.0"
    page_height = "297.0"
    page_rotation = "0"
    scale = get_scale(page_width |> String.to_float(), page_height |> String.to_float())
    div_top = get_dynamic_top(scale)

    booking_rewards_lead_map
    |> Map.merge(%{
      "div_top" => div_top,
      "scale" => scale,
      "page_rotation" => page_rotation,
      "page_height" => page_height,
      "page_width" => page_width
    })
    |> generate_booking_reward_html()
    |> HtmlHelper.generate_pdf_from_html(page_width, page_height)
    |> upload_pdf_on_s3(prefix, booking_rewards_lead.id)
    |> get_pdf_url()
    |> case do
      nil ->
        {:error, "Something went wrong file generating booking rewards PDF."}

      imgx_pdf_url ->
        insert_booking_rewards_pdf_url(booking_rewards_lead, imgx_pdf_url, user_map)
        {:ok, imgx_pdf_url}
    end
  end

  defp generate_booking_reward_html(booking_rewards_lead) do
    {:safe, html} = Phoenix.View.render(BnApisWeb.V1.BookingRewardsView, "booking_reward.html", booking_rewards_lead: booking_rewards_lead)

    html |> IO.iodata_to_binary()
  end

  defp upload_pdf_on_s3(file_path, prefix, brl_id) do
    InvoiceHelper.upload_invoice(prefix, file_path, brl_id)
  end

  defp get_pdf_url(path) do
    path |> S3Helper.get_imgix_url()
  end

  defp insert_booking_rewards_pdf_url(booking_rewards_lead, pdf_url, user_map) do
    BookingRewardsLead.update(booking_rewards_lead, %{"booking_rewards_pdf" => pdf_url}, user_map)
  end

  defp get_scale(page_width, page_height) do
    # 1 mm = 3.7795275591 pixel
    [page_width * 3.7795275591 / 500, page_height * 3.7795275591 / 1100] |> Enum.min()
  end

  ## in pixels
  defp get_dynamic_top(scale) do
    100 * scale
  end
end
