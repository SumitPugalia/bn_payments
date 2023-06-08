defmodule BnApisWeb.BilldeskController do
  use BnApisWeb, :controller
  require Logger

  alias BnApis.Helpers.ApplicationHelper
  alias BnPayments.Responses
  alias BnApis.Packages

  ##############################################################################
  #  Webhook Callbacks
  ##############################################################################

  def webhook(conn, %{"orderid" => _user_order_id, "transaction_response" => txn_response} = params) do
    channel = "billdesk-webhook"
    payload_message = params |> Poison.encode!()
    ApplicationHelper.notify_on_slack("BillDesk Webhook Received - #{payload_message}", channel)

    with {:ok, response} <- BnPayments.Utils.decrypt_with_HMAC(txn_response),
         {:ok, txn} <- Responses.create_transaction_response(response),
         :ok <- Packages.update_payment_from_txn(txn) do
      conn |> put_status(:ok) |> json(%{})
    else
      {:error, response} ->
        Logger.error("Received unverified response as callback #{inspect(response)} for #{inspect(payload_message)}")
        ApplicationHelper.notify_on_slack("Received unverified response as callback - #{inspect(response)} for #{inspect(payload_message)}", channel)
        conn |> put_status(:ok) |> json(%{})

      {:user_order_check, user_order} ->
        Logger.error("Received callback for user order #{inspect(user_order)} which is not in created status")
        conn |> put_status(:ok) |> json(%{})

      error ->
        ApplicationHelper.notify_on_slack("BillDesk Webhook Action Failed with error - #{inspect(error)} for #{inspect(payload_message)}", channel)
        conn |> put_status(:ok) |> json(%{})
    end
  end

  def webhook(conn, params) do
    channel = "billdesk-webhook"
    payload_message = params |> Poison.encode!()
    ApplicationHelper.notify_on_slack("Unhandled BillDesk Webhook Received - #{payload_message}", channel)
    conn |> put_status(:ok) |> json(%{})
  end

  def return_url(conn, %{"orderid" => _user_order_id, "transaction_response" => txn_response} = params) do
    channel = "billdesk-webhook"
    payload_message = params |> Poison.encode!()
    ApplicationHelper.notify_on_slack("BillDesk Webhook Received - #{payload_message} from Return URL", channel)

    with {:ok, response} <- BnPayments.Utils.decrypt_with_HMAC(txn_response),
         {:ok, txn} <- Responses.create_transaction_response(response),
         :ok <- Packages.update_payment_from_txn(txn) do
      render(conn, "index.html")
    else
      {:error, response} ->
        Logger.error("Received unverified response as callback #{inspect(response)} for #{inspect(payload_message)} from Return URL")
        ApplicationHelper.notify_on_slack("Received unverified response as callback - #{inspect(response)} for #{inspect(payload_message)}", channel)
        render(conn, "index.html")

      {:user_order_check, user_order} ->
        Logger.error("Received callback for user order #{inspect(user_order)} which is not in created status from Return URL")
        render(conn, "index.html")

      error ->
        ApplicationHelper.notify_on_slack("BillDesk Webhook Action Failed with error - #{inspect(error)} for #{inspect(payload_message)} from Return URL", channel)
        render(conn, "index.html")
    end
  end

  def return_url(conn, params) do
    channel = "billdesk-webhook"
    payload_message = params |> Poison.encode!()
    ApplicationHelper.notify_on_slack("Unhandled BillDesk Webhook Received - #{payload_message} from Return URL", channel)
    render(conn, "index.html")
  end

  ##############################################################################
  #  INTERNAL FUNCTIONS
  ##############################################################################
end
