defmodule BnApis.PaytmWebhooks do
  @moduledoc """
  The PaytmWebhooks context.
  """

  import Ecto.Query, warn: false
  alias BnApis.Repo
  alias BnApis.PaytmWebhooks.PaytmWebhook

  @doc """
  Returns the list of paytm_webhooks.

  ## Examples

      iex> list_paytm_webhooks()
      [%PaytmWebhook{}, ...]

  """
  def list_paytm_webhooks do
    Repo.all(PaytmWebhook)
  end

  @doc """
  Gets a single paytm_webhook.

  Raises `Ecto.NoResultsError` if the Paytm webhook does not exist.

  ## Examples

      iex> get_paytm_webhook!(123)
      %PaytmWebhook{}

      iex> get_paytm_webhook!(456)
      ** (Ecto.NoResultsError)

  """
  def get_paytm_webhook!(id), do: Repo.get!(PaytmWebhook, id)

  @doc """
  Creates a paytm_webhook.

  ## Examples

      iex> create_paytm_webhook_row(%{field: value})
      {:ok, %PaytmWebhook{}}

      iex> create_paytm_webhook_row(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_paytm_webhook_row(params \\ %{}) do
    ch =
      PaytmWebhook.changeset(%PaytmWebhook{}, %{
        txn_id: params["TXNID"],
        txn_date: params["TXNDATE"],
        txn_amount: params["TXNAMOUNT"],
        subs_id: params["SUBS_ID"],
        status: params["STATUS"],
        resp_msg: params["RESPMSG"],
        resp_code: params["RESPCODE"],
        payment_mode: params["PAYMENTMODE"],
        order_id: params["ORDERID"],
        mid: params["MID"],
        gateway_name: params["GATEWAYNAME"],
        cust_id: params["CUSTID"],
        currency: params["CURRENCY"],
        bank_txn_id: params["BANKTXNID"],
        bank_name: params["BANKNAME"],
        checksum_hash: params["CHECKSUMHASH"],
        masked_account_number: params["maskedAccountNumber"],
        issuing_bank_logo: params["issuingBankLogo"],
        issuing_bank: params["issuingBank"],
        ifsc: params["ifsc"],
        txn_date_time: params["TXNDATETIME"],
        merc_unq_ref: params["MERC_UNQ_REF"],
        total_retry_count: params["totalRetryCount"],
        retries_left: params["retriesLeft"],
        last_retry_done_attempted_time: params["lastRetryDoneAttemptedTime"],
        retry_allowed: params["retryAllowed"],
        error_message: params["errorMessage"],
        error_code: params["errorCode"]
      })

    Repo.insert!(ch)
  end
end
