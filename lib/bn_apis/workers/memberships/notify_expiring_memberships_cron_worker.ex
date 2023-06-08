defmodule BnApis.Memberships.NotifyExpiringMembershipsCronWorker do
  alias BnApis.Repo

  alias BnApis.Memberships.Membership
  alias BnApis.Organizations.Broker

  import Ecto.Query

  def perform() do
    notify_expiring_memberships()
  end

  def notify_expiring_memberships() do
    tomorrow = Timex.now() |> Timex.Timezone.convert("Asia/Kolkata") |> Timex.shift(days: 1)
    tomorrow_start = tomorrow |> Timex.beginning_of_day() |> DateTime.to_unix()
    tomorrow_end = tomorrow |> Timex.end_of_day() |> DateTime.to_unix()

    Membership
    |> join(:inner, [m], bro in Broker, on: m.broker_id == bro.id)
    |> where([m], m.status == ^Membership.active_status())
    |> where([m], m.last_order_status == ^Membership.order_success())
    |> where([m], m.current_end >= ^tomorrow_start)
    |> where([m], m.current_end <= ^tomorrow_end)
    |> select([m, bro], %{
      broker_phone_number: m.broker_phone_number,
      broker_name: bro.name
    })
    |> Repo.all()
    |> Enum.each(fn map ->
      notify_broker(map.broker_phone_number, map.broker_name)
      Process.sleep(500)
    end)
  end

  def notify_broker(broker_phone_number, broker_name) do
    Exq.enqueue(
      Exq,
      "send_sms",
      BnApis.Whatsapp.SendWhatsappMessageWorker,
      [
        broker_phone_number,
        "membership_autopay_reminder",
        [broker_name]
      ]
    )
  end
end
