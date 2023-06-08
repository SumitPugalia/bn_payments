defmodule BnApisWeb.SmsController do
  use BnApisWeb, :controller

  alias BnApis.Sms.SmsRequest
  alias BnApis.Helpers.{SmsHelper}

  def message_status_webhook(conn, params) do
    params |> parse_params() |> SmsRequest.create_or_update_sms_request()
    conn |> put_status(:ok) |> json(%{message: "Success"})
  end

  def mobtexting_message_status_webhook(conn, params) do
    params |> parse_mobtexting_params |> SmsRequest.create_or_update_sms_request()
    conn |> put_status(:ok) |> json(%{message: "Success"})
  end

  def broadcast(conn, %{"message" => message, "title" => title, "using_sms" => using_sms, "using_fcm" => using_fcm}) do
    Exq.enqueue(Exq, "custom_notification", BnApis.CustomNotificationWorker, [title, message, using_sms, using_fcm])
    conn |> put_status(:ok) |> json(%{message: "Success"})
  end

  defp parse_params(params) do
    %{
      "message_sid" => params["MessageSid"],
      "to" => params["To"],
      "message_status_id" => params["MessageStatus"] |> SmsHelper.get_status_id_by_name()
    }
  end

  defp parse_mobtexting_params(params) do
    %{
      "message_sid" => params["id"],
      "message_status_id" => params["status"] |> SmsHelper.get_status_id_by_name()
    }
  end
end
