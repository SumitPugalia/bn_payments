defmodule BnApis.Helpers.SmsService do
  @moduledoc """
  Main service switch for SMS service which decides if we should call API or mock the response.
  """
  alias BnApis.Helpers.SmsService.HTTP

  def send_sms(to, message \\ "", add_sms_token \\ true, send_whatsapp \\ true), do: send_sms(to, message, add_sms_token, send_whatsapp, "")

  @spec send_sms(to :: String.t(), message :: String.t(), boolean(), boolean(), String.t()) :: tuple
  def send_sms(to, message, add_sms_token, send_whatsapp, template) do
    get_module().send_sms(to, message, add_sms_token, send_whatsapp, template)
  end

  defp get_module() do
    :bn_apis
    |> Application.get_env(__MODULE__, [])
    |> Keyword.get(:sms_service_module, HTTP)
  end
end
