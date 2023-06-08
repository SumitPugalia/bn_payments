defmodule BnApisWeb.Admin.InvoiceController do
  use BnApisWeb, :controller

  alias BnApis.Helpers.Connection
  alias BnApis.Helpers.Utils
  alias BnApis.Stories.Invoice
  alias BnApis.Helpers.Otp
  alias BnApis.Rewards.InvoicePayout

  action_fallback BnApisWeb.FallbackController

  @ankur_phone_number "9987580172"

  def mark_invoice_to_be_paid(conn, %{"invoice_uuids" => uuid_list, "otp" => otp}) do
    logged_in_user = Connection.get_employee_logged_in_user(conn)
    user_map = Utils.get_user_map(logged_in_user)

    if valid_2fa_otp?(uuid_list, logged_in_user.uuid, otp) do
      failures = Invoice.mark_to_be_paid(uuid_list, logged_in_user.employee_role_id , user_map)
      render(conn, BnApisWeb.InvoiceView, "mark_invoice_to_be_paid.json", %{failures: failures})
    else
      {:error, "Invalid OTP"}
    end
  end

  def action_otp(conn, %{"invoice_uuids" => invoice_uuids}) do
    logged_in_user = Connection.get_employee_logged_in_user(conn)
    otp_map = create_2fa_otp(invoice_uuids, logged_in_user.uuid)
    masked_invoice_number = Enum.map(invoice_uuids, &"XXXXXX#{String.slice(&1, -4..-1)}") |> Enum.join(",")

    message =
      "2FA OTP for RAZORPAY for invoice number/s #{masked_invoice_number} is: #{otp_map.otp}. DO NOT SHARE THIS OTP with any BrokerNetwork Employee or Channel Partner. Please call +919373200897 to report anyone who asks for your OTP."

    Exq.enqueue(Exq, "send_sms", BnApis.SendSmsWorker, [@ankur_phone_number, message, true, true, "2fa_legal_entity_poc_otp"])

    conn
    |> put_status(:ok)
    |> json(%{message: "OTP has been sent to XXXXXX0172 for authentication", phone_number: "XXXXXX0172"})
  end

  def get_payment_logs(conn, params = %{"invoice_id" => invoice_id}) do
    page_no = Map.get(params, "page" , "1") |> String.to_integer()
    with {:ok, data} <- InvoicePayout.get_payment_logs(invoice_id, page_no) do
      conn
      |> put_status(:ok)
      |> json(data)
    end
  end

  defp create_2fa_otp(invoice_uuids, user_id) do
    key = Enum.join(["razorpay-automate", Enum.sort(invoice_uuids), user_id], "_")
    map = Otp.fetch_otp(key)
    if is_nil(map.otp), do: Otp.generate_otp(key), else: map
  end

  defp valid_2fa_otp?(invoice_uuids, user_id, otp) do
    key = Enum.join(["razorpay-automate", Enum.sort(invoice_uuids), user_id], "_")
    otp_map = Otp.fetch_otp(key)

    if otp_map.otp == otp, do: Otp.delete(key)
    otp_map.otp == otp
  end
end
