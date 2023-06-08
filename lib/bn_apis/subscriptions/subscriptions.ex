defmodule BnApis.Subscriptions do
  @moduledoc """
  The Subscriptions context.
  """

  import Ecto.Query, warn: false
  alias BnApis.Repo

  alias BnApis.Accounts.Credential
  alias BnApis.Subscriptions
  alias BnApis.Subscriptions.Subscription
  alias BnApis.Subscriptions.SubscriptionStatus
  alias BnApis.Subscriptions.SubscriptionInvoice
  alias BnApis.Subscriptions.MatchPlusSubscription
  alias BnApis.Helpers.ApplicationHelper
  alias BnApis.Helpers.ExternalApiHelper

  # for 10 years
  @total_count 120
  @update_status_retry_interval_in_seconds 5
  @update_registration_status_number_of_retries 5

  def update_status_retry_interval_in_seconds do
    @update_status_retry_interval_in_seconds
  end

  # Apis for App
  def create_subscription(session_data) do
    broker_id = session_data |> get_in(["profile", "broker_id"])

    match_plus_subscription =
      MatchPlusSubscription.find_or_create!(broker_id)
      |> Repo.preload([:latest_subscription])

    latest_subscription = match_plus_subscription.latest_subscription

    if is_nil(latest_subscription) or
         !Enum.member?([Subscription.created_status(), Subscription.authenticated_status()], latest_subscription.status) do
      cond do
        check_eligility_for_subscription_creation(match_plus_subscription) ->
          Repo.transaction(fn ->
            try do
              response = create_razorpay_subscription()
              subscription_params = get_params_for_subscription(response, broker_id, match_plus_subscription.id)
              subscription = Subscription.create_subscription!(subscription_params)
              MatchPlusSubscription.update_latest_subscription!(match_plus_subscription, subscription.id)

              %{
                id: subscription.id,
                status: subscription.status,
                razorpay_subscription_id: subscription.razorpay_subscription_id
              }
            rescue
              _ ->
                Repo.rollback("Unable to store data")
            end
          end)

        true ->
          {:error, "There is an active subscription running already!"}
      end
    else
      {:ok,
       %{
         id: latest_subscription.id,
         status: latest_subscription.status,
         razorpay_subscription_id: latest_subscription.razorpay_subscription_id
       }}
    end
  end

  def update_subscription(params, session_data) do
    broker_id = session_data |> get_in(["profile", "broker_id"])

    case params do
      %{
        "id" => id
      } ->
        subscription = Subscription.get_subscription(id)

        cond do
          is_nil(subscription) ->
            {:error, "No such subscription found"}

          subscription.broker_id != broker_id ->
            {:error, "You are not authorised to update this subscription"}

          true ->
            response = get_razorpay_subscription(subscription.razorpay_subscription_id)

            subscription_params = get_params_for_subscription(response, broker_id, subscription.match_plus_subscription_id)

            Repo.transaction(fn ->
              try do
                subscription = Subscription.update_subscription!(subscription, subscription_params)
                update_subscription_invoices(subscription)

                %{
                  id: subscription.id,
                  status: subscription.status,
                  razorpay_subscription_id: subscription.razorpay_subscription_id
                }
              rescue
                _ ->
                  Repo.rollback("Unable to store data")
              end
            end)
        end

      _ ->
        {:error, "Invalid params"}
    end
  end

  def cancel_subscription(params, session_data) do
    broker_id = session_data |> get_in(["profile", "broker_id"])

    case params do
      %{
        "id" => id
      } ->
        subscription = Subscription.get_subscription(id)

        cond do
          is_nil(subscription) ->
            {:error, "No such subscription found"}

          subscription.broker_id != broker_id ->
            {:error, "You are not authorised to delete this subscription"}

          subscription.status == "cancelled" ->
            {:error, "Subscription has already been cancelled"}

          true ->
            response = cancel_razorpay_subscription(subscription.razorpay_subscription_id)

            subscription_params = get_params_for_subscription(response, broker_id, subscription.match_plus_subscription_id)

            Repo.transaction(fn ->
              try do
                subscription = Subscription.update_subscription!(subscription, subscription_params)
                update_subscription_invoices(subscription)

                %{
                  id: subscription.id,
                  status: subscription.status,
                  razorpay_subscription_id: subscription.razorpay_subscription_id
                }
              rescue
                _ ->
                  Repo.rollback("Unable to cancel subscription")
              end
            end)
        end

      _ ->
        {:error, "Invalid params"}
    end
  end

  def handle_subscription_webhook(razorpay_event_id, subscription_id, params) do
    subscription_statuses =
      SubscriptionStatus
      |> where([s], s.razorpay_event_id == ^razorpay_event_id)
      |> Repo.all()

    if length(subscription_statuses) == 0 do
      Repo.transaction(fn ->
        try do
          subscription = Repo.get_by(Subscription, razorpay_subscription_id: subscription_id)

          if not is_nil(subscription) do
            Subscription.update_status!(subscription, params[:status], params)
            response = get_razorpay_subscription(subscription.razorpay_subscription_id)

            subscription_params = get_params_for_subscription(response, subscription.broker_id, subscription.match_plus_subscription_id)

            subscription = Subscription.update_subscription!(subscription, subscription_params)
            update_subscription_invoices(subscription)
          end
        rescue
          _ ->
            Repo.rollback("Unable to process subscription webhook")
        end
      end)
    end
  end

  def update_subscription_invoices(subscription) do
    response = get_razorpay_subscription_invoices(subscription.razorpay_subscription_id)

    response["items"]
    |> Enum.each(fn invoice ->
      subscription_invoice = SubscriptionInvoice.fetch_by_invoice_id(invoice["id"])

      if is_nil(subscription_invoice) do
        invoice_params = get_params_for_subscription_invoice(invoice)
        SubscriptionInvoice.create_subscription_invoice!(subscription, invoice_params)
      end
    end)
  end

  def fetch_subscriptions_history(session_data) do
    broker_id = session_data |> get_in(["profile", "broker_id"])

    match_plus_subscription =
      MatchPlusSubscription
      |> Repo.get_by(broker_id: broker_id)
      |> Repo.preload(subscriptions: [:subscription_invoices])

    response =
      if not is_nil(match_plus_subscription) do
        match_plus_subscription.subscriptions
        |> Enum.reduce([], fn subscription, acc ->
          subscription.subscription_invoices
          |> Enum.reduce(acc, fn invoice, acc ->
            item = %{
              subscription_id: subscription.id,
              razorpay_subscription_id: subscription.razorpay_subscription_id,
              razorpay_invoice_id: invoice.razorpay_invoice_id,
              invoice_billing_start: invoice.billing_start,
              invoice_billing_end: invoice.billing_end,
              invoice_amount: invoice.amount,
              invoice_paid_at: invoice.paid_at
            }

            [item | acc]
          end)
        end)
        |> Enum.sort_by(fn item -> {item[:invoice_paid_at]} end, &>=/2)
      else
        []
      end

    response
  end

  def mark_subscription_as_registered(params, session_data) do
    broker_id = session_data |> get_in(["profile", "broker_id"])

    case params do
      %{
        "id" => id
      } ->
        subscription = Subscription.get_subscription(id)

        cond do
          is_nil(subscription) ->
            {:error, "No such subscription found"}

          subscription.broker_id != broker_id ->
            {:error, "You are not authorised to update this subscription"}

          true ->
            response = get_razorpay_subscription(subscription.razorpay_subscription_id)

            subscription_params =
              get_params_for_subscription(response, broker_id, subscription.match_plus_subscription_id)
              |> Map.put(:is_client_side_registration_successful, true)

            Repo.transaction(fn ->
              try do
                subscription = Subscription.update_subscription!(subscription, subscription_params)
                update_subscription_invoices(subscription)

                if subscription.status != Subscription.active_status() do
                  Exq.enqueue_in(
                    Exq,
                    "update_subscription_status",
                    Subscriptions.update_status_retry_interval_in_seconds(),
                    BnApis.Subscriptions.UpdateSubscriptionStatusWorker,
                    [id, @update_registration_status_number_of_retries]
                  )
                end

                %{
                  id: subscription.id,
                  status: subscription.status,
                  razorpay_subscription_id: subscription.razorpay_subscription_id
                }
              rescue
                _ ->
                  Repo.rollback("Unable to store data")
              end
            end)
        end

      _ ->
        {:error, "Invalid params"}
    end
  end

  def send_owner_listings_notifications(title, message, phone_numbers) do
    phone_numbers
    |> Enum.each(fn phone_number ->
      Exq.enqueue(
        Exq,
        "send_notification",
        BnApis.Subscriptions.OwnerListingsNotificationWorker,
        [title, message, phone_number]
      )
    end)
  end

  # Private methods
  defp check_eligility_for_subscription_creation(match_plus_subscription) do
    match_plus_subscription =
      match_plus_subscription
      |> Repo.preload([:latest_subscription, :subscriptions])

    cond do
      Enum.member?(
        Enum.map(match_plus_subscription.subscriptions, fn s -> s.status end),
        Subscription.active_status()
      ) ->
        false

      !is_nil(match_plus_subscription.latest_subscription) and
          Enum.member?(
            [Subscription.created_status(), Subscription.authenticated_status()],
            match_plus_subscription.latest_subscription.status
          ) ->
        false

      match_plus_subscription.status_id == MatchPlusSubscription.active_status_id() ->
        false

      true ->
        true
    end
  end

  defp create_razorpay_subscription() do
    plan_id = ApplicationHelper.get_razorpay_match_plus_plan_id()
    auth_key = ApplicationHelper.get_razorpay_auth_key()

    {_status_code, response} =
      ExternalApiHelper.create_razorpay_subscription(
        plan_id,
        @total_count,
        auth_key
      )

    response
  end

  def get_razorpay_subscription(razorpay_subscription_id) do
    auth_key = ApplicationHelper.get_razorpay_auth_key()

    {_status_code, response} =
      ExternalApiHelper.get_razorpay_subscription(
        razorpay_subscription_id,
        auth_key
      )

    response
  end

  defp get_razorpay_subscription_invoices(razorpay_subscription_id) do
    auth_key = ApplicationHelper.get_razorpay_auth_key()

    {_status_code, response} =
      ExternalApiHelper.get_razorpay_subscription_invoices(
        razorpay_subscription_id,
        auth_key
      )

    response
  end

  defp cancel_razorpay_subscription(razorpay_subscription_id) do
    auth_key = ApplicationHelper.get_razorpay_auth_key()

    {status_code, response} =
      ExternalApiHelper.cancel_razorpay_subscription(
        razorpay_subscription_id,
        auth_key
      )

    if status_code == 200,
      do: response,
      else: get_razorpay_subscription(razorpay_subscription_id)
  end

  def get_params_for_subscription(response, broker_id, match_plus_subscription_id) do
    credential = Credential.get_credential_from_broker_id(broker_id)

    %{
      razorpay_plan_id: response["plan_id"],
      razorpay_subscription_id: response["id"],
      created_at: response["created_at"],
      razorpay_customer_id: response["customer_id"],
      status: response["status"],
      short_url: response["short_url"],
      payment_method: response["payment_method"],
      start_at: response["start_at"],
      ended_at: response["ended_at"],
      charge_at: response["charge_at"],
      total_count: response["total_count"],
      paid_count: response["paid_count"],
      remaining_count: response["remaining_count"],
      current_start: response["current_start"],
      current_end: response["current_end"],
      broker_phone_number: credential.phone_number,
      broker_id: broker_id,
      match_plus_subscription_id: match_plus_subscription_id,
      razorpay_data: response
    }
  end

  defp get_params_for_subscription_invoice(invoice) do
    %{
      razorpay_invoice_id: invoice["id"],
      razorpay_invoice_status: invoice["status"],
      razorpay_order_id: invoice["order_id"],
      razorpay_payment_id: invoice["payment_id"],
      razorpay_data: invoice,
      created_at: invoice["created_at"],
      razorpay_customer_id: invoice["customer_id"],
      short_url: invoice["short_url"],
      invoice_number: invoice["invoice_number"],
      billing_start: invoice["billing_start"],
      billing_end: invoice["billing_end"],
      paid_at: invoice["paid_at"],
      amount: invoice["amount"],
      amount_paid: invoice["amount_paid"],
      amount_due: invoice["amount_due"],
      date: invoice["date"],
      partial_payment: invoice["partial_payment"],
      tax_amount: invoice["tax_amount"],
      taxable_amount: invoice["taxable_amount"],
      currency: invoice["currency"]
    }
  end
end
