defmodule BnApis.Helpers.PaytmMembershipHelper do
  alias BnApis.Helpers.ApplicationHelper
  alias BnApis.Helpers.PaytmMembershipHelper
  alias BnApis.Helpers.ExternalApiHelper
  alias BnApis.Memberships.Membership
  alias BnApis.Memberships
  alias BnApis.PaytmWebhooks

  def notify_paytm_webhook_on_slack(payload) do
    channel = "paytm_webhook_dump"
    payload_message = payload |> Poison.encode!()
    ApplicationHelper.notify_on_slack("Paytm webhook payload - #{payload_message}", channel)
  end

  def handle_subscription_webhook(params) do
    PaytmMembershipHelper.notify_paytm_webhook_on_slack(params)
    paytm_subscription_id = params["SUBS_ID"]
    Memberships.handle_subscription_webhook(paytm_subscription_id, params)
    PaytmWebhooks.create_paytm_webhook_row(params)
  end

  def create_checksum(payload) do
    merchant_key = ApplicationHelper.get_paytm_merchant_key()
    body = payload |> Poison.encode!()

    {checksum, _} = System.cmd("ruby", ["#{File.cwd!()}/lib/ruby/paytm_helper.rb", "create_checksum", "#{merchant_key}", "#{body}"])

    checksum
  end

  def get_subscription_details(subscription_id) do
    merchant_id = ApplicationHelper.get_paytm_merchant_id()
    url = ApplicationHelper.get_paytm_url() <> "subscription/checkStatus"

    body = %{
      "mid" => merchant_id,
      "subsId" => subscription_id
    }

    checksum = body |> Poison.encode!() |> PaytmMembershipHelper.create_checksum()
    len = String.length(checksum)
    checksum = String.slice(checksum, 0, len - 1)

    payload = %{
      "body" => body,
      "head" => %{
        "signature" => checksum,
        "tokenType" => "AES"
      }
    }

    headers = [{"Content-Type", "application/json"}]

    {_status, response} =
      ExternalApiHelper.perform(
        :post,
        url,
        payload,
        headers,
        recv_timeout: 500_000
      )

    response
  end

  def get_subscription_order_details(order_id) do
    merchant_id = ApplicationHelper.get_paytm_merchant_id()
    url = ApplicationHelper.get_paytm_url() <> "v3/order/status"

    body = %{
      "mid" => merchant_id,
      "orderId" => order_id
    }

    checksum = body |> Poison.encode!() |> PaytmMembershipHelper.create_checksum()
    len = String.length(checksum)
    checksum = String.slice(checksum, 0, len - 1)

    payload = %{
      "body" => body,
      "head" => %{
        "signature" => checksum,
        "tokenType" => "AES"
      }
    }

    headers = [{"Content-Type", "application/json"}]

    {_status, response} =
      ExternalApiHelper.perform(
        :post,
        url,
        payload,
        headers,
        recv_timeout: 500_000
      )

    response
  end

  def create_subscription(cust_id, order_id, start_date, expiry_date, start_transaction_amount, renewal_amount) do
    merchant_id = ApplicationHelper.get_paytm_merchant_id()
    website_mode = ApplicationHelper.get_paytm_website_mode()
    callback_url = ApplicationHelper.get_bn_apis_base_url() <> "api/v1/paytm_webhooks"
    url = ApplicationHelper.get_paytm_url() <> "subscription/create?mid=#{merchant_id}&orderId=#{order_id}"

    body = %{
      "requestType" => "NATIVE_SUBSCRIPTION",
      "mid" => merchant_id,
      "websiteName" => website_mode,
      "orderId" => order_id,
      "subscriptionAmountType" => "FIX",
      "subscriptionStartDate" => start_date,
      "subscriptionGraceDays" => "2",
      "subscriptionEnableRetry" => "1",
      "subscriptionRetryCount" => "2",
      "subscriptionFrequency" => "1",
      "subscriptionFrequencyUnit" => Membership.subscription_frequency_unit(),
      "subscriptionExpiryDate" => expiry_date,
      "renewalAmount" => renewal_amount,
      "autoRenewal" => true,
      "autoRetry" => true,
      # "communicationManager" => true,
      "txnAmount" => %{
        "value" => start_transaction_amount,
        "currency" => "INR"
      },
      "userInfo" => %{
        "custId" => cust_id
      },
      "callbackUrl" => callback_url
    }

    checksum = body |> Poison.encode!() |> PaytmMembershipHelper.create_checksum()
    len = String.length(checksum)
    checksum = String.slice(checksum, 0, len - 1)

    payload = %{
      "body" => body,
      "head" => %{
        "signature" => checksum
      }
    }

    headers = [{"Content-Type", "application/json"}]

    {_status, response} =
      ExternalApiHelper.perform(
        :post,
        url,
        payload,
        headers,
        recv_timeout: 500_000
      )

    response
  end

  def cancel_subscription(subscription_id) do
    merchant_id = ApplicationHelper.get_paytm_merchant_id()
    url = ApplicationHelper.get_paytm_url() <> "subscription/cancel"

    body = %{
      "mid" => merchant_id,
      "subsId" => subscription_id
    }

    checksum = body |> Poison.encode!() |> PaytmMembershipHelper.create_checksum()
    len = String.length(checksum)
    checksum = String.slice(checksum, 0, len - 1)

    payload = %{
      "body" => body,
      "head" => %{
        "signature" => checksum,
        "tokenType" => "AES"
      }
    }

    headers = [{"Content-Type", "application/json"}]

    ExternalApiHelper.perform(
      :post,
      url,
      payload,
      headers,
      recv_timeout: 500_000
    )
  end
end
