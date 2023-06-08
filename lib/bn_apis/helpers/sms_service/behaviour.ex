defmodule BnApis.Helpers.SmsService.Behaviour do
  @callback send_sms(String.t(), String.t(), boolean(), boolean()) :: {:ok | :error, any()}
  @callback send_sms(String.t(), String.t(), boolean(), boolean(), String.t()) :: {:ok | :error, any()}
end
