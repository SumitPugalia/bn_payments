defmodule BnApis.Whatsapp.SendWhatsappMessageWorker do
  alias BnApis.Helpers.WhatsappHelper

  def perform(phone_number, template, vars \\ [], opts \\ %{}, is_media_message \\ false, button_replies \\ [], media_var \\ nil) do
    WhatsappHelper.send_whatsapp_message(phone_number, template, vars, opts, is_media_message, button_replies, media_var)
  end
end
