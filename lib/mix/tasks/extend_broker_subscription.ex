defmodule Mix.Tasks.ExtendBrokerSubscription do
  use Mix.Task

  alias BnApis.Repo

  alias BnApis.Orders.Order
  alias BnApis.Orders.MatchPlus
  alias BnApis.Organizations.Broker
  alias BnApis.Packages.UserPackage
  alias BnApis.Helpers.Time

  import Ecto.Query

  def run(_) do
    Mix.Task.run("app.start", [])
    razorpay_subs_active_status_id = MatchPlus.get_active_status_id()
    razorpay_subs_inactive_status_id = MatchPlus.inactive_status_id()
    billdesk_subs_active_status_id = UserPackage.active_status()
    extend_for_subscribed_brokers(razorpay_subs_active_status_id, billdesk_subs_active_status_id)
    extend_for_expired_subscription_brokers(razorpay_subs_inactive_status_id, razorpay_subs_active_status_id)
  end

  def extend_for_subscribed_brokers(
        razorpay_subs_active_status_id,
        billdesk_subs_active_status_id
      ) do
    razorpay_latest_paid_orders =
      MatchPlus
      |> join(:inner, [mp], br in Broker, on: mp.broker_id == br.id)
      |> join(:inner, [mp, br], lo in Order, on: mp.latest_paid_order_id == lo.id)
      |> where([mp, _br, _lo], mp.status_id == ^razorpay_subs_active_status_id)
      |> select([mp, br, lo], {br.id, lo})
      |> Repo.all()

    Enum.each(razorpay_latest_paid_orders, fn {broker_id, order} ->
      if not is_nil(order.current_end) do
        current_end =
          Time.epoch_to_naive(order.current_end * 1000)
          |> Timex.Timezone.convert("Asia/Kolkata")
          |> Timex.shift(days: 45)
          |> Timex.end_of_day()
          |> DateTime.to_unix()

        with {:ok, %Order{}} <- Order.changeset(order, %{current_end: current_end}) |> Repo.update() do
          IO.puts("Order extend for broker with broker_id => #{broker_id}")
        else
          {:error, changeset} ->
            IO.inspect("============== Error:  =============")
            IO.inspect("Issue while extending subs(razorpay) for broker with broker_id: #{broker_id}.")
            IO.inspect(changeset.errors)
        end
      end
    end)

    brokers_to_exclude = [585, 23239, 116_485]

    billdesk_paid_orders =
      UserPackage
      |> where([up], up.status == ^billdesk_subs_active_status_id and up.broker_id not in ^brokers_to_exclude)
      |> Repo.all()

    Enum.each(billdesk_paid_orders, fn order ->
      if not is_nil(order.current_end) do
        current_end =
          Time.epoch_to_naive(order.current_end * 1000)
          |> Timex.Timezone.convert("Asia/Kolkata")
          |> Timex.shift(days: 45)
          |> Timex.end_of_day()
          |> DateTime.to_unix()

        with {:ok, %UserPackage{}} <- UserPackage.changeset(order, %{current_end: current_end}) |> Repo.update() do
          IO.puts("Order extend for broker with broker_id => #{order.broker_id}")
        else
          {:error, changeset} ->
            IO.inspect("============== Error:  =============")
            IO.inspect("Issue while extending subs(billdesk) for broker with broker_id: #{order.broker_id}.")
            IO.inspect(changeset.errors)
        end
      end
    end)
  end

  def extend_for_expired_subscription_brokers(razorpay_subs_inactive_status_id, razorpay_subs_active_status_id) do
    broker_who_got_subs_expired_and_renewed_via_billdesk = [
      116_485,
      51579,
      5351,
      100_263,
      101_414,
      114_922,
      116_485,
      116_728,
      129_442,
      131_082,
      133_649,
      136_943,
      21318,
      23239,
      585,
      77337,
      82349
    ]

    razorpay_latest_paid_orders =
      MatchPlus
      |> join(:inner, [mp], br in Broker, on: mp.broker_id == br.id)
      |> join(:inner, [mp, br], lo in Order, on: mp.latest_paid_order_id == lo.id)
      |> where(
        [mp, _br, lo],
        mp.status_id == ^razorpay_subs_inactive_status_id and lo.current_end >= 1_675_189_800 and mp.broker_id not in ^broker_who_got_subs_expired_and_renewed_via_billdesk
      )
      |> select([mp, _br, lo], {mp, lo})
      |> Repo.all()

    Enum.each(razorpay_latest_paid_orders, fn {match_plus, order} ->
      if not is_nil(order.current_end) do
        # 15th April
        current_end = 1_681_583_399

        with {:ok, %Order{}} <- Order.changeset(order, %{current_end: current_end}) |> Repo.update() do
          IO.puts("Order extend for broker with broker_id => #{match_plus.broker_id}")
        else
          {:error, changeset} ->
            IO.inspect("============== Error:  =============")
            IO.inspect("Issue while extending expired subs for broker with broker_id: #{match_plus.broker_id}.")
            IO.inspect(changeset.errors)
        end

        with {:ok, %MatchPlus{}} <- MatchPlus.changeset(match_plus, %{status_id: razorpay_subs_active_status_id}) |> Repo.update() do
          IO.puts("Order extend for broker with broker_id => #{match_plus.broker_id}")
        else
          {:error, changeset} ->
            IO.inspect("============== Error:  =============")
            IO.inspect("Issue while marking MatchPlus active for broker with broker_id: #{match_plus.broker_id}.")
            IO.inspect(changeset.errors)
        end
      end
    end)
  end
end
