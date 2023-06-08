defmodule BnApis.Orders.UpdateOrderStatusCronWorker do
  alias BnApis.Orders
  alias BnApis.Orders.Order
  alias BnApis.Orders.OrderPayment
  alias BnApis.Repo
  alias BnApis.Helpers.FcmNotification
  alias BnApis.Accounts.Credential
  # alias BnApis.Helpers.ApplicationHelper

  import Ecto.Query

  def perform() do
    # channel = ApplicationHelper.get_slack_channel()
    # ApplicationHelper.notify_on_slack("Started - order update cron", channel)

    update_uncaptured_orders()
    # ApplicationHelper.notify_on_slack("order update cron - updated_uncaptured_orders", channel)
    update_client_side_only_updated_orders()
    # ApplicationHelper.notify_on_slack("order update cron - updated_client_side_only_updated_orders", channel)

    # ApplicationHelper.notify_on_slack("Finished - order update cron", channel)
  end

  def update_uncaptured_orders() do
    Order
    |> join(:left, [o], op in OrderPayment, on: op.order_id == o.id)
    |> where(
      [o, op],
      o.status == ^Order.paid_status() and o.is_captured == false and
        (is_nil(op.id) or op.razorpay_payment_status != ^OrderPayment.captured_status())
    )
    |> Repo.all()
    |> Enum.each(fn order ->
      update_order_status(order)
    end)
  end

  def update_client_side_only_updated_orders() do
    Order
    |> where(
      [o],
      o.is_client_side_payment_successful == true and
        (o.status == ^Order.created_status() or o.status == ^Order.attempted_status())
    )
    |> Repo.all()
    |> Enum.each(fn order ->
      update_order_status(order)
      Process.sleep(500)
    end)
  end

  def update_order_status(order) do
    response = Orders.get_razorpay_order(order.razorpay_order_id)

    if response["status"] == Order.paid_status() do
      broker_id = order.broker_id
      order_params = Orders.get_params_for_order(response, broker_id, order.match_plus_id)
      Order.update_order!(order, order_params)
      # notify app about the update
      send_notification(broker_id)
    end
  end

  def send_notification(broker_id) do
    credential = Credential.get_credential_from_broker_id(broker_id)
    type = "SUBSCRIPTION_ORDER_CONFIRMED"

    FcmNotification.send_push(
      credential.fcm_id,
      %{data: %{}, type: type},
      credential.id,
      credential.notification_platform
    )
  end
end
