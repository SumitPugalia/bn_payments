defmodule Mix.Tasks.MoveSubscriptionsToPayments do
  use Mix.Task
  import Ecto.Query
  alias BnApis.Repo
  alias BnApis.Accounts.Credential
  alias BnApis.Orders.Order
  alias BnApis.Orders.MatchPlus
  alias BnApis.Subscriptions.MatchPlusSubscription

  @shortdoc "move subscriptions to payments"
  def run(_) do
    Mix.Task.run("app.start", [])
    create_dummy_entries_in_match_plus()
  end

  # 9922419042 | 67    | MAHENDRA HANDE
  # 9923019256 | 325   | Bindu Vishwakarma
  # 7350921653 | 634   | Aniket
  # 9325213309 | 1082  | Partner BALVEER
  # 8180858096 | 18713 | Sachin Randive

  def create_dummy_entries_in_match_plus() do
    phone_numbers = ["9922419042", "9923019256", "7350921653", "9325213309", "8180858096"]
    IO.puts("STARTED THE TASK - move subscriptions to payments")

    Credential
    |> where([c], c.phone_number in ^phone_numbers and c.active == true)
    |> Repo.all()
    |> Enum.each(fn credential ->
      Repo.transaction(fn ->
        credential |> create_dummy_entry()
      end)
    end)

    IO.puts("FINISHED THE TASK - move subscriptions to payments")
  end

  def create_dummy_entry(credential) do
    broker_id = credential.broker_id
    match_plus = MatchPlus.find_or_create!(broker_id) |> Repo.preload([:latest_order])
    latest_order = match_plus.latest_order

    match_plus_subscription =
      Repo.get_by(MatchPlusSubscription, broker_id: broker_id)
      |> Repo.preload([:latest_subscription])

    if is_nil(latest_order) and not is_nil(match_plus_subscription) and
         match_plus_subscription.status_id == MatchPlusSubscription.active_status_id() do
      subscription = match_plus_subscription.latest_subscription
      subscription_created_at = subscription.created_at
      subscription_current_start = subscription.current_start
      # subscription_current_end = subscription.current_end

      phone_number = credential.phone_number

      dummy_razorpay_order_id = "order_dummy_launch_correction_#{phone_number}"

      ch =
        Order.changeset(%Order{}, %{
          match_plus_id: match_plus.id,
          razorpay_order_id: dummy_razorpay_order_id,
          created_at: subscription_created_at,
          status: "paid",
          amount: 199_900,
          amount_due: 0,
          amount_paid: 0,
          currency: "INR",
          broker_phone_number: phone_number,
          broker_id: broker_id
        })

      order = Repo.insert!(ch)

      order_current_start = subscription_current_start
      {:ok, order_current_start_datetime} = DateTime.from_unix(order_current_start)

      order_current_end =
        order_current_start_datetime
        |> Timex.Timezone.convert("Asia/Kolkata")
        |> Timex.shift(days: 1)
        |> Timex.end_of_day()
        |> Timex.shift(days: 60)
        |> DateTime.to_unix()

      ch =
        Order.order_billing_dates_changeset(order, %{
          current_start: order_current_start,
          current_end: order_current_end
        })

      order = Repo.update!(ch)

      MatchPlus.update_latest_order!(match_plus, order.id)

      MatchPlus
      |> Repo.get_by(id: order.match_plus_id)
      |> MatchPlus.verify_and_update_status()
    end
  end
end
