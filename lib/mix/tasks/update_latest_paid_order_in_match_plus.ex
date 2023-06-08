defmodule Mix.Tasks.UpdateLatestPaidOrderInMatchPlus do
  use Mix.Task
  alias BnApis.Repo
  alias BnApis.Orders.Order
  alias BnApis.Orders.MatchPlus

  @shortdoc "update latest paid order in match plus"
  def run(_) do
    Mix.Task.run("app.start", [])
    update_latest_paid_order_in_match_plus()
  end

  def update_latest_paid_order_in_match_plus() do
    IO.puts("STARTED THE TASK - update latest paid order in match plus")

    MatchPlus
    |> Repo.all()
    |> Enum.each(fn match_plus ->
      latest_paid_order = Order.get_latest_paid_order_of_a_broker(match_plus.broker_id)
      latest_paid_order_id = if is_nil(latest_paid_order), do: nil, else: latest_paid_order.id
      MatchPlus.update_latest_paid_order!(match_plus, latest_paid_order_id)
    end)

    IO.puts("FINISHED THE TASK - update latest paid order in match plus")
  end
end
