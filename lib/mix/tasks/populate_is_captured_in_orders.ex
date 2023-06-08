defmodule Mix.Tasks.PopulateIsCapturedInOrders do
  use Mix.Task
  import Ecto.Query
  alias BnApis.Repo
  alias BnApis.Orders.Order

  @shortdoc "populate is_captured in orders"
  def run(_) do
    Mix.Task.run("app.start", [])
    populate_is_captured_in_orders()
  end

  def populate_is_captured_in_orders() do
    IO.puts("STARTED THE TASK - populate is_captured in orders")

    Order
    |> where([o], o.is_captured == false)
    |> Repo.all()
    |> Enum.each(fn order ->
      captured_payment = Order.get_captured_payment(order)

      if not is_nil(captured_payment) do
        Order.changeset(order, %{is_captured: true}) |> Repo.update!()
      end
    end)

    IO.puts("FINISHED THE TASK - populate is_captured in orders")
  end
end
