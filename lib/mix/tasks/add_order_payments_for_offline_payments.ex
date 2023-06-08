defmodule Mix.Tasks.AddOrderPaymentsForOfflinePayments do
  use Mix.Task

  import Ecto.Query

  alias BnApis.Repo
  alias BnApis.Orders.Order
  alias BnApis.Orders.OrderPayment

  @shortdoc "Add order payments for offline payments "
  def run(_) do
    Mix.Task.run("app.start", [])
    create_order_payments()
  end

  def create_order_payments() do
    order_id_search = "%" <> "dummy" <> "%"

    Order
    |> where([o], ilike(o.razorpay_order_id, ^order_id_search))
    |> join(:left, [o], p in OrderPayment, on: o.id == p.order_id)
    |> where([o, p], is_nil(p.order_id))
    |> Repo.all()
    |> Enum.each(fn order ->
      params = %{
        razorpay_order_id: order.razorpay_order_id,
        razorpay_payment_id: "pay_" <> order.razorpay_order_id,
        razorpay_payment_status: "captured",
        amount: order.amount,
        captured: true,
        created_at: order.created_at
      }

      create_order_payment(order, params)
    end)
  end

  defp create_order_payment(order, params) do
    try do
      OrderPayment.create_order_payment!(order, params)
      IO.puts("create order payment for order #{inspect(order)} with params #{inspect(params)}")
    rescue
      error ->
        IO.puts("============== Error:  =============")
        IO.puts("Failed create order payment for order #{inspect(order)} with params #{inspect(params)}")
        IO.puts(error)
    end
  end
end
