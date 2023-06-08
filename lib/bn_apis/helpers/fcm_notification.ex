defmodule BnApis.Helpers.FcmNotification do
  import Ecto.Query
  alias Pigeon.FCM
  alias BnApis.Repo
  alias BnApis.Accounts.Credential
  alias BnApis.Notifications.Request
  require Logger

  def send_push(regid, data, broker_id, _platform) when is_nil(regid) or regid == "" do
    Logger.info("Fcm Id is empty for data: #{inspect(data)} and credential id: #{broker_id}")
  end

  def send_push(regid, data, broker_id, platform) do
    # Adding action key based on intent if action not already provided
    action = Map.get(data, :action, parse_notif_data(data[:data]))
    data = Map.put(data, :action, action)

    # adding compatibility for android, uses "text" field at some places and "message" field at others
    # adding compatibility for android, uses "text" field at some places and "message" field at others
    data = if not is_nil(data[:data]) do
      extended_data = if is_nil(Map.get(data[:data], "text")), do: Map.put(data[:data], "text", data[:data]["message"]), else: data[:data]
      Map.put(data, :data, extended_data)
    else
      Map.put(data, :data, %{})
    end

    title = Map.get(data[:data], "title")
    body = Map.get(data[:data], "subtitle")
    body = Map.get(data[:data], "message", body)
    campaign_id = Map.get(data[:data], "campaign_id")

    notif_data =
      if not is_nil(platform) and platform |> String.downcase() == "ios",
        do: %{"body" => body, "title" => title, "click_action" => data.type, "sound" => "default"},
        else: %{}

    notif_data =
      if data.type == "NEW_MATCH_ALERT" or data.type == "NEW_MATCH_ALERT_NOTIFICATION" or (data.type == "WEB_ALERT" and campaign_id) do
        Map.put(notif_data, "mutable_content", true)
      else
        notif_data
      end

    request = Request.create_params(broker_id, data, regid, notif_data) |> Request.create_request()

    data = Request.modify_notif_data(request, data)

    notif = FCM.Notification.new(regid, notif_data, data) |> FCM.Notification.put_priority(:high) |> FCM.push()

    Request.update_notif_response(request, notif)

    case notif.status do
      :success ->
        case notif.response do
          [success: regid] ->
            {:ok, regid}

          [invalid_registration: _regid] ->
            {:error, "FCM Invalid registration!"}

          [not_registered: regid] ->
            handle_regid({:not_registered, regid})

          _ ->
            {:error, "FCM unknown error!"}
        end

      :unauthorized ->
        {:error, "Bad fcm key!"}

      :not_registered ->
        handle_regid({:not_registered, regid})

      error ->
        {:error, "FCM error: #{error}!"}
    end
  end

  def handle_push(%FCM.Notification{status: :success} = n) do
    IO.puts("success! checks each reg ID")
    for response <- n.response, do: handle_regid(response)
  end

  def handle_push(%FCM.Notification{status: _error} = _n) do
    IO.puts("entire push batch failed!")
  end

  def handle_regid({:success, _regid}) do
    IO.puts("success!")
  end

  def handle_regid({:update, {_old_regid, _new_regid}}) do
    IO.puts("replace the regid in the database!")
  end

  def handle_regid({:invalid_registration, _regid}) do
    IO.puts("remove it!")
  end

  def handle_regid({:not_registered, regid}) do
    # Mark it uninstalled
    IO.puts("INSIDE NOT REGISTERED")
    creds = Credential |> where([c], c.fcm_id == ^regid) |> Repo.all()

    creds
    |> Enum.each(fn cred ->
      cred |> Credential.update_installed_flag() |> Repo.update!()
    end)
  end

  def handle_regid({_error, _regid}) do
    IO.puts("Some unknown error happened!")
  end

  defp parse_notif_data(nil), do: ""
  defp parse_notif_data(%{"intent" => %{"action" => action}}), do: action
  defp parse_notif_data(%{"intent" => intent}) when is_binary(intent), do: intent
  defp parse_notif_data(_), do: ""
end
