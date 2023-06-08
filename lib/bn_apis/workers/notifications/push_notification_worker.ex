defmodule BnApis.Notifications.PushNotificationWorker do
  def perform(regid, data, broker_id, platform) do
    atom_key_data = for {key, val} <- data, into: %{}, do: {if(is_binary(key), do: String.to_atom(key), else: key), val}
    BnApis.Helpers.FcmNotification.send_push(regid, atom_key_data, broker_id, platform)
  end
end
