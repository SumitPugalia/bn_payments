defmodule BnApis.UpdateUserOnSendbird do
  alias BnApis.Helpers.ExternalApiHelper

  def perform(payload, user_id, metadata \\ nil) do
    ExternalApiHelper.update_user_on_sendbird(payload, user_id)

    if not is_nil(metadata) do
      ExternalApiHelper.update_user_metadata_on_sendbird(metadata, user_id)
    end
  end
end
