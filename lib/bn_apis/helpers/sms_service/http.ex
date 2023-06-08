defmodule BnApis.Helpers.SmsService.HTTP do
  alias BnApis.Helpers.{SmsHelper, ApplicationHelper, ExternalApiHelper, WhatsappHelper}
  alias BnApis.Helpers.SmsService.Behaviour
  @mobtexting_sender "BRKRNW"

  @behaviour Behaviour

  # def send_sms(phone_number, message) do
  #   {:ok, "_success"}
  # end

  @doc """
  Sends an sms with `message`, `to` given phone number `from` our registered phone number.

  ## Example:
       iex> BnApis.Helpers.SmsService.send_sms("+91 9953530923", "Hello 123, 123, mic check")
       {:ok,
        %{"message" => "Sent from your Twilio trial account - Hello 123, 123, mic check",
          "from" => "+17312480242", "to" => "+919953530431"}}
  """

  @impl Behaviour
  @spec send_sms(to :: String.t(), message :: String.t(), boolean(), boolean()) :: tuple
  def send_sms(to, message \\ "", add_sms_token \\ true, send_whatsapp \\ true, template \\ "") do
    to = format_to(to) |> to_override

    if send_whatsapp == true do
      WhatsappHelper.send_whatsapp_message(to, "generic", [message])
    end

    # maybe_send_sms(to, message, add_sms_token)
    deliver_sms(to, message, add_sms_token, template)
  end

  @doc ~S"""
  - sends an sms with given `message`, to `to` phone number from `sender`.
  ## Example:
       Sms.Thirdparty.Mobtexting.send_sms(
         "ANARCK",
         "+919953530431",
         "Hello 123, 123, mic check")
       {:ok,
        %{"charges" => "1.0000", "customid" => "", "customid1" => "",
          "id" => "44c5a2d7-5d18-4cfb-8d17-fa69e96a0d36:1", "iso_code" => nil,
          "length" => 18, "mobile" => "919953530431", "status" => "AWAITING-DLR",
          "submitted_at" => "2019-09-12 14:57:53", "units" => 1}}
  """
  def send_sms_via_mobtexting(to, message, add_sms_token \\ true, sender \\ @mobtexting_sender) do
    to = format_to(to) |> to_override
    message = message |> process_message(add_sms_token)
    {status_code, response} = ExternalApiHelper.send_sms_via_mobtexting(to, message, sender)

    if status_code == 200 do
      response |> SmsHelper.create_mobtexting_sms_request(message)
      {:ok, response}
    else
      {:error, response}
    end
  end

  defp process_message(message, add_sms_token) do
    if add_sms_token, do: "<#> BrokerNetworkApp: " <> message <> "\n" <> ApplicationHelper.sms_token(), else: message
  end

  defp to_override(phone_number) do
    env = ApplicationHelper.get_env()

    cond do
      env == :prod ->
        phone_number

      env == :test ->
        phone_number

      true ->
        regex_phone_number = Regex.replace(~r/^(\+91)/, phone_number, "")

        if env == :dev and ApplicationHelper.whitelisted_dev_twilio_tos() =~ ~r/#{regex_phone_number}/ do
          phone_number
        else
          ApplicationHelper.default_dev_twilio_to()
        end
    end
  end

  # Format phone number to a valid twilio phone
  # Only valid for Indian and UAE Numbers
  defp format_to(phone_number) do
    # removes spaces
    phone_number = Regex.replace(~r/\s/, phone_number, "")
    maybe_insert_country_code(phone_number)
  end

  defp maybe_insert_country_code("+" <> _ = number), do: number
  defp maybe_insert_country_code(number), do: "+91#{number}"

  defp deliver_sms("+91" <> phone_number = to, message, add_sms_token, template) do
    template_id = SmsHelper.get_template_id_by_name(template)

    if not is_nil(template_id) do
      message = message |> process_message(add_sms_token)
      sender_id = SmsHelper.get_sender_id()

      args =
        %{
          ApiKey: ApplicationHelper.get_bulksms_api_key(),
          EntityID: ApplicationHelper.get_bulksms_entity_id(),
          SenderID: sender_id,
          TemplateID: template_id,
          Mobileno: phone_number,
          Message: message
        }
        |> Enum.reduce("", fn {k, v}, acc -> acc <> "#{k}=#{v}" <> "&" end)

      url = ApplicationHelper.get_bulksms_url() <> "?" <> args
      {status_code, response} = ExternalApiHelper.perform(:get, URI.encode(url), "", [], [], true)

      if status_code == 200 do
        delivery_status = if String.contains?(response, "Sent Successfully"), do: "sent", else: "failed"
        sid = DateTime.utc_now() |> DateTime.to_unix(:millisecond) |> Integer.to_string()
        sid = sid <> SecureRandom.urlsafe_base64(8)

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
    else
      {:error, %{message: "Template not found"}}
    end
  end

  defp deliver_sms(_to, _message, _add_sms_token, _template), do: {:ok, %{message: "SMS could not be delivered"}}
end
