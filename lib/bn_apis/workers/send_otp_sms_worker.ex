defmodule BnApis.SendOtpSmsWorker do
  alias BnApis.Helpers.OtpSmsHelper

  def perform(phone_number, otp) do
    OtpSmsHelper.send_otp_sms(phone_number, otp)
  end
end
