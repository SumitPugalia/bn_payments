defmodule Mix.Tasks.CreateDummyOrderForInvestor do
  use Mix.Task
  import Ecto.Query
  alias BnApis.Repo
  alias BnApis.Accounts.Credential
  alias BnApis.Orders.Order
  alias BnApis.Orders.MatchPlus

  @shortdoc "create dummy order for investor"
  def run(_) do
    Mix.Task.run("app.start", [])
    create_dummy_entries_in_match_plus()
  end

  # 9137458869 | 18000    | Nityanand Gowda

  def create_dummy_entries_in_match_plus() do
    phone_numbers = ["9137458869"]
    IO.puts("STARTED THE TASK - create dummy order for investor")

    Credential
    |> where([c], c.phone_number in ^phone_numbers and c.active == true)
    |> Repo.all()
    |> Enum.each(fn credential ->
      Repo.transaction(fn ->
        credential |> create_dummy_entry()
      end)
    end)

    IO.puts("FINISHED THE TASK - create dummy order for investor")
  end

  def create_dummy_entry(credential) do
    broker_id = credential.broker_id
    match_plus = MatchPlus.find_or_create!(broker_id) |> Repo.preload([:latest_order])
    latest_order = match_plus.latest_order

    if is_nil(latest_order) do
      phone_number = credential.phone_number

      dummy_razorpay_order_id = "order_dummy_for_inv_#{phone_number}"

      dummy_created_at =
        Timex.now()
        |> Timex.Timezone.convert("Asia/Kolkata")
        |> Timex.beginning_of_day()
        |> DateTime.to_unix()

      ch =
        Order.changeset(%Order{}, %{
          match_plus_id: match_plus.id,
          razorpay_order_id: dummy_razorpay_order_id,
          created_at: dummy_created_at,
          status: "paid",
          amount: 1_499_900,
          amount_due: 0,
          amount_paid: 0,
          currency: "INR",
          broker_phone_number: phone_number,
          broker_id: broker_id
        })

      order = Repo.insert!(ch)

      order_current_start = dummy_created_at
      {:ok, order_current_start_datetime} = DateTime.from_unix(order_current_start)

      order_current_end =
        order_current_start_datetime
        |> Timex.Timezone.convert("Asia/Kolkata")
        |> Timex.shift(days: 1)
        |> Timex.end_of_day()
        |> Timex.shift(days: 180)
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
