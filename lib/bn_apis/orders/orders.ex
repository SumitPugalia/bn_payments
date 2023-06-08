defmodule BnApis.Orders do
  @moduledoc """
  The Orders context.
  """

  import Ecto.Query, warn: false
  alias BnApis.Repo

  alias BnApis.Accounts.Credential
  alias BnApis.Orders.{MatchPlusPackage, Order, OrderStatus, OrderPayment, MatchPlus}
  alias BnApis.Helpers.{ApplicationHelper, AuditedRepo, ExternalApiHelper, Time, Utils}
  # Apis for App
  def create_order(session_data, _params = %{"package_uuid" => package_uuid}) do
    broker_id = session_data |> get_in(["profile", "broker_id"])
    match_plus = MatchPlus.find_or_create!(broker_id) |> Repo.preload([:latest_order])

    match_plus_package = MatchPlusPackage.fetch_active_package_from_uuid(package_uuid)

    if is_nil(match_plus_package) do
      {:error, "MatchPlus package not found"}
    else
      match_plus_package_id = match_plus_package.id

      latest_order = match_plus.latest_order

      if is_nil(latest_order) or match_plus_package_id != latest_order.match_plus_package_id or
           !Enum.member?([Order.created_status(), Order.attempted_status()], latest_order.status) do
        Repo.transaction(fn ->
          try do
            response = create_razorpay_order(match_plus_package)
            order_params = get_params_for_order(response, broker_id, match_plus.id)
            order = Order.create_order!(order_params, match_plus_package_id)
            MatchPlus.update_latest_order!(match_plus, order.id)

            %{
              id: order.id,
              status: order.status,
              amount: order.amount,
              razorpay_order_id: order.razorpay_order_id
            }
          rescue
            _ ->
              Repo.rollback("Unable to store data")
          end
        end)
      else
        {:ok,
         %{
           id: latest_order.id,
           status: latest_order.status,
           amount: latest_order.amount,
           razorpay_order_id: latest_order.razorpay_order_id
         }}
      end
    end
  end

  def create_order(_params, _session_data), do: {:error, "MatchPlus package not found"}

  def update_order(params, session_data) do
    broker_id = session_data |> get_in(["profile", "broker_id"])

    case params do
      %{
        "id" => id
      } ->
        order = Order.get_order(id)

        cond do
          is_nil(order) ->
            {:error, "No such order found"}

          order.broker_id != broker_id ->
            {:error, "You are not authorised to update this order"}

          true ->
            response = get_razorpay_order(order.razorpay_order_id)
            order_params = get_params_for_order(response, broker_id, order.match_plus_id)

            Repo.transaction(fn ->
              try do
                order = Order.update_order!(order, order_params)

                %{
                  id: order.id,
                  status: order.status,
                  amount: order.amount,
                  razorpay_order_id: order.razorpay_order_id
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

  def handle_order_webhook(razorpay_event_id, razorpay_order_id, _params) do
    order_statuses =
      OrderStatus
      |> where([s], s.razorpay_event_id == ^razorpay_event_id)
      |> Repo.all()

    if length(order_statuses) == 0 do
      Repo.transaction(fn ->
        try do
          order = Repo.get_by(Order, razorpay_order_id: razorpay_order_id)

          if not is_nil(order) do
            response = get_razorpay_order(order.razorpay_order_id)
            order_params = get_params_for_order(response, order.broker_id, order.match_plus_id)
            order_params = order_params |> Map.merge(%{razorpay_event_id: razorpay_event_id})
            Order.update_order!(order, order_params)
          end
        rescue
          _ ->
            Repo.rollback("Unable to process order webhook")
        end
      end)
    end
  end

  def update_order_payments(order) do
    response = get_razorpay_order_payments(order.razorpay_order_id)

    response["items"]
    |> Enum.each(fn payment ->
      order_payment = OrderPayment.fetch_by_payment_id(payment["id"])
      payment_params = get_params_for_order_payment(payment)

      if is_nil(order_payment) do
        OrderPayment.create_order_payment!(order, payment_params)
      else
        OrderPayment.update_order_payment!(order_payment, payment_params)
      end
    end)
  end

  def fetch_broker_orders_history(broker_id) do
    match_plus =
      MatchPlus
      |> Repo.get_by(broker_id: broker_id)
      |> Repo.preload([:latest_order, :latest_paid_order, orders: [:order_payments]])

    orders =
      if not is_nil(match_plus) do
        match_plus.orders
        |> Enum.reduce([], fn order, acc ->
          order.order_payments
          |> Enum.reduce(acc, fn payment, acc ->
            item = %{
              order_id: order.id,
              razorpay_order_id: order.razorpay_order_id,
              razorpay_order_status: order.status,
              razorpay_order_invoice_url: order.invoice_url,
              razorpay_payment_id: payment.razorpay_payment_id,
              razorpay_payment_status: payment.razorpay_payment_status,
              payment_amount: payment.amount,
              payment_created_at: payment.created_at
            }

            [item | acc]
          end)
        end)
        |> Enum.sort_by(fn item -> {item[:payment_created_at]} end, &>=/2)
      else
        []
      end

    %{
      match_plus: MatchPlus.get_data(match_plus),
      paid_orders: orders
    }
  end

  def mark_order_as_paid(params, session_data) do
    broker_id = session_data |> get_in(["profile", "broker_id"])

    case params do
      %{
        "id" => id
      } ->
        order = Order.get_order(id)

        cond do
          is_nil(order) ->
            {:error, "No such order found"}

          order.broker_id != broker_id ->
            {:error, "You are not authorised to update this order"}

          true ->
            response = get_razorpay_order(order.razorpay_order_id)

            order_params =
              get_params_for_order(response, broker_id, order.match_plus_id)
              |> Map.put(:is_client_side_payment_successful, true)

            Repo.transaction(fn ->
              try do
                order = Order.update_order!(order, order_params)

                %{
                  id: order.id,
                  status: order.status,
                  amount: order.amount,
                  razorpay_order_id: order.razorpay_order_id
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

  def update_order_payment_as_captured(order_payment) do
    capture_razorpay_order_payment(
      order_payment.razorpay_payment_id,
      order_payment.amount,
      order_payment.currency
    )
  end

  def update_gst(params, session_data) do
    broker_id = session_data |> get_in(["profile", "broker_id"])

    case params do
      %{
        "id" => id
      } ->
        order = Order.get_order(id)

        cond do
          is_nil(order) ->
            {:error, "No such order found"}

          order.broker_id != broker_id ->
            {:error, "You are not authorised to access this order"}

          order.status != Order.paid_status() ->
            {:error, "Invoice can only be generated for paid orders"}

          !order_belongs_to_current_month(order) ->
            {:error, "GST information can only be updated for current month orders"}

          true ->
            Repo.transaction(fn ->
              try do
                order = Order.update_gst!(order, params)

                %{
                  id: order.id,
                  invoice_url: order.invoice_url,
                  message: "GST details have been captured successfully. You will be notified once Invoice is ready!"
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

  def create_offline_payment_entry(logged_in_user, credential, match_plus_package, notes) do
    broker_id = credential.broker_id
    phone_number = credential.phone_number
    dummy_razorpay_order_id = "order_dummy_for_broker_#{phone_number}_#{Date.utc_today() |> Date.to_string()}"

    match_plus = MatchPlus.find_or_create!(broker_id) |> Repo.preload([:latest_paid_order])
    latest_paid_order = match_plus.latest_paid_order

    order_current_start =
      cond do
        not is_nil(latest_paid_order) && latest_paid_order.current_end > DateTime.to_unix(DateTime.utc_now()) ->
          {:ok, order_current_start_datetime} = DateTime.from_unix(latest_paid_order.current_end)

          order_current_start_datetime
          |> Timex.Timezone.convert("Asia/Kolkata")
          |> Timex.shift(days: 1)

        true ->
          Timex.now()
          |> Timex.Timezone.convert("Asia/Kolkata")
      end
      |> Timex.beginning_of_day()
      |> DateTime.to_unix()

    created_at = Timex.now() |> Timex.Timezone.convert("Asia/Kolkata") |> DateTime.to_unix()

    ch =
      Order.changeset(%Order{}, %{
        match_plus_id: match_plus.id,
        razorpay_order_id: dummy_razorpay_order_id,
        created_at: created_at,
        status: "paid",
        amount: match_plus_package.amount_in_rupees * 100,
        amount_due: 0,
        amount_paid: match_plus_package.amount_in_rupees * 100,
        currency: "INR",
        broker_phone_number: phone_number,
        broker_id: broker_id,
        notes: notes
      })

    user_map = Utils.get_user_map(logged_in_user)
    {:ok, order} = AuditedRepo.insert(ch, user_map)

    {:ok, order_current_start_datetime} = DateTime.from_unix(order_current_start)

    order_current_end =
      order_current_start_datetime
      |> Timex.Timezone.convert("Asia/Kolkata")
      |> Timex.shift(days: 1)
      |> Timex.end_of_day()
      |> Timex.shift(days: match_plus_package.validity_in_days)
      |> DateTime.to_unix()

    ch =
      Order.order_billing_dates_changeset(order, %{
        current_start: order_current_start,
        current_end: order_current_end
      })

    {:ok, order} = AuditedRepo.update(ch, user_map)

    params = %{
      razorpay_order_id: order.razorpay_order_id,
      razorpay_payment_id: "pay_" <> order.razorpay_order_id,
      razorpay_payment_status: "captured",
      amount: order.amount,
      captured: true,
      created_at: created_at
    }

    OrderPayment.create_order_payment!(order, params)

    MatchPlus.update_latest_order!(match_plus, order.id)

    MatchPlus
    |> Repo.get_by(id: order.match_plus_id)
    |> MatchPlus.verify_and_update_status()
  end

  # Private methods
  # defp check_eligility_for_order_creation(match_plus) do
  #   match_plus = match_plus
  #   |> Repo.preload([:latest_order, :orders])
  #   cond do
  #     (!is_nil(match_plus.latest_order) and Enum.member?([Order.created_status, Order.attempted_status], match_plus.latest_order.status)) ->
  #       false
  #
  #     match_plus.status_id == MatchPlus.active_status_id ->
  #       false
  #
  #     true ->
  #       true
  #   end
  # end

  defp order_belongs_to_current_month(order) do
    {current_time, beginning_of_month, end_of_month_minus_one_day, end_of_month_five_pm, end_of_month} = Time.get_current_month_limits_in_unix()
    c_payment = Order.get_captured_payment(order)

    cond do
      c_payment.created_at > beginning_of_month and c_payment.created_at < end_of_month_minus_one_day and current_time < end_of_month_minus_one_day ->
        true

      c_payment.created_at > end_of_month_minus_one_day and c_payment.created_at < end_of_month and current_time < end_of_month_five_pm ->
        true

      true ->
        false
    end
  end

  defp create_razorpay_order(match_plus_package) do
    match_plus_price =
      if is_nil(match_plus_package),
        do: MatchPlus.price(),
        else: match_plus_package.amount_in_rupees * 100

    currency = MatchPlus.currency()
    auth_key = ApplicationHelper.get_razorpay_auth_key()

    {_status_code, response} =
      ExternalApiHelper.create_razorpay_order(
        match_plus_price,
        currency,
        auth_key
      )

    response
  end

  def get_razorpay_order(razorpay_order_id) do
    auth_key = ApplicationHelper.get_razorpay_auth_key()

    {_status_code, response} =
      ExternalApiHelper.get_razorpay_order(
        razorpay_order_id,
        auth_key
      )

    response
  end

  defp capture_razorpay_order_payment(razorpay_payment_id, payment_amount, currency) do
    auth_key = ApplicationHelper.get_razorpay_auth_key()

    {_status_code, response} =
      ExternalApiHelper.capture_razorpay_order_payment(
        razorpay_payment_id,
        payment_amount,
        currency,
        auth_key
      )

    response
  end

  defp get_razorpay_order_payments(razorpay_order_id) do
    auth_key = ApplicationHelper.get_razorpay_auth_key()

    {_status_code, response} =
      ExternalApiHelper.get_razorpay_order_payments(
        razorpay_order_id,
        auth_key
      )

    response
  end

  def get_params_for_order(response, broker_id, match_plus_id) do
    credential = Credential.get_credential_from_broker_id(broker_id)

    credential =
      if not is_nil(credential),
        do: credential,
        else: Credential.get_any_credential_from_broker_id(broker_id)

    %{
      razorpay_order_id: response["id"],
      created_at: response["created_at"],
      status: response["status"],
      amount: response["amount"],
      amount_due: response["amount_due"],
      amount_paid: response["amount_paid"],
      currency: response["currency"],
      broker_phone_number: credential.phone_number,
      broker_id: broker_id,
      match_plus_id: match_plus_id,
      razorpay_data: response
    }
  end

  defp get_params_for_order_payment(payment) do
    %{
      razorpay_data: payment,
      razorpay_payment_id: payment["id"],
      razorpay_order_id: payment["order_id"],
      razorpay_payment_status: payment["status"],
      amount: payment["amount"],
      currency: payment["currency"],
      created_at: payment["created_at"],
      invoice_id: payment["invoice_id"],
      international: payment["international"],
      method: payment["method"],
      amount_refunded: payment["amount_refunded"],
      refund_status: payment["refund_status"],
      captured: payment["captured"],
      description: payment["description"],
      card_id: payment["card_id"],
      bank: payment["bank"],
      wallet: payment["wallet"],
      vpa: payment["vpa"],
      tax: payment["tax"],
      fee: payment["fee"],
      email: payment["email"],
      contact: payment["contact"],
      notes: payment["notes"],
      error_code: payment["error_code"],
      error_description: payment["error_description"],
      error_source: payment["error_source"],
      error_step: payment["error_step"],
      error_reason: payment["error_reason"]
    }
  end
end
