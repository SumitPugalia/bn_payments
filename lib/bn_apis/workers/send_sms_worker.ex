defmodule BnApis.SendSmsWorker do
  alias BnApis.Helpers.SmsService

  def perform(phone_number, message, add_sms_token \\ true, send_whatsapp \\ true, template \\ "") do
    SmsService.send_sms(phone_number, message, add_sms_token, send_whatsapp, template)
  end
end
