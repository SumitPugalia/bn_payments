defmodule BnApis.Helpers.OtpSmsHelper.Behaviour do
  @callback send_otp_sms_api(any(), any()) :: {:ok, any()}
end

defmodule BnApis.Helpers.OtpSmsHelper do
  @module :bn_apis
          |> Application.get_env(__MODULE__, [])
          |> Keyword.get(:module_name, __MODULE__)

  @behaviour BnApis.Helpers.OtpSmsHelper.Behaviour
  alias BnApis.Helpers.{ApplicationHelper, SmsHelper, ExternalApiHelper}

  def send_otp_sms(to, otp), do: @module.send_otp_sms_api(to, otp)

  @impl true
  def send_otp_sms_api(to, otp) do
    # to = if String.contains?(to, "+91"), do: to, else: "+91" <> to
    message = "#{otp} is your OTP for BrokerNetwork."
    template_id = SmsHelper.get_template_id_by_name("general_otp")
    sender_id = SmsHelper.get_sender_id()

    args =
      %{
        ApiKey: ApplicationHelper.get_bulksms_api_key(),
        EntityID: ApplicationHelper.get_bulksms_entity_id(),
        SenderID: sender_id,
        TemplateID: template_id,
        Mobileno: to,
        Message: message
      }
      |> Enum.reduce("", fn {k, v}, acc -> acc <> "#{k}=#{v}" <> "&" end)

    url = ApplicationHelper.get_bulksms_url() <> "?" <> args

    # Tesla.get(URI.encode(url))
    {status_code, response} = ExternalApiHelper.perform(:get, URI.encode(url), "", [], [], true)

    if status_code == 200 do
      delivery_status = if String.contains?(response, "Sent Successfully"), do: "sent", else: "failed"
      sid = DateTime.utc_now() |> DateTime.to_unix(:millisecond) |> Integer.to_string()
      sid = sid <> SecureRandom.urlsafe_base64(8)
      to = if String.contains?(to, "+91"), do: to, else: "+91" <> to

      SmsHelper.create_sms_request(%{
        "sid" => sid,
        "to" => to,
        "body" => message,
        "status" => delivery_status
      })

      {:ok, %{message: response}}
    else
      {:error, %{message: response}}
    end
  end
end
