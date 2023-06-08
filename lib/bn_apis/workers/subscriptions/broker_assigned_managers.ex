defmodule BnApis.Subscriptions.BrokerAssignedManagers do
  import Ecto.Query, warn: false
  alias BnApis.Repo
  alias BnApis.Accounts.OwnersBrokerEmployeeMapping
  alias BnApis.Orders.MatchPlus
  alias BnApis.Orders.Order
  alias BnApis.Helpers.WhatsappHelper

  def perform() do
    now = Timex.now() |> Timex.Timezone.convert("Asia/Kolkata") |> Timex.beginning_of_day()
    day_at_minus_5 = now |> Timex.shift(days: 5) |> Timex.end_of_day() |> DateTime.to_unix()

    MatchPlus
    |> join(:inner, [mp], o in Order, on: mp.latest_paid_order_id == o.id)
    |> join(:left, [mp, o], obem in OwnersBrokerEmployeeMapping, on: obem.broker_id == mp.broker_id and obem.active == true)
    |> where([mp, o], mp.status_id == ^1 and o.status == ^"paid" and fragment("? < ?", o.current_end, ^day_at_minus_5))
    |> Repo.all()
    |> Repo.preload([:latest_order, :latest_paid_order, broker: [:credentials]])
    |> Enum.each(fn match_plus ->
      broker = match_plus.broker
      credential = match_plus.broker.credentials |> List.last()

      obem =
        OwnersBrokerEmployeeMapping
        |> where([obm], obm.broker_id == ^match_plus.broker_id and obm.active == ^true)
        |> Repo.all()
        |> Repo.preload([:employees_credentials])
        |> List.last()

      order =
        if is_nil(match_plus.latest_paid_order),
          do: match_plus.latest_order,
          else: match_plus.latest_paid_order

      if not is_nil(obem) do
        to_number = obem.employees_credentials.phone_number
        {:ok, datetime} = DateTime.from_unix(order.current_end)
        end_date = datetime |> Timex.Timezone.convert("Asia/Kolkata") |> Timex.format!("%d %b, %Y", :strftime)

        message = "Owners supply subsciption for your assigned broker #{broker.name}, #{credential.phone_number} is expiring on #{end_date}. Please get in touch with the broker."

        WhatsappHelper.send_whatsapp_message(to_number, "generic", [message])
      end
    end)
  end
end
