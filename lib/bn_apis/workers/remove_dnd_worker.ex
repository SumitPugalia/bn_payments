defmodule RemoveDNDWorker do
  alias BnApis.Helpers.ExternalApiHelper

  def perform(phone_number) do
    ExternalApiHelper.remove_dnd(phone_number)
  end
end
