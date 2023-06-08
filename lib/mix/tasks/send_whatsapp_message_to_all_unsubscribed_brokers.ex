defmodule Mix.Tasks.SendWhatsappMessageToAllUnsubscribedBrokers do
  use Mix.Task

  alias BnApis.Repo

  alias BnApis.Memberships.MatchPlusMembership
  alias BnApis.Orders.MatchPlus
  alias BnApis.Organizations.Broker
  alias BnApis.Accounts.Credential

  import Ecto.Query

  @subscription_msg_template_mumbai "owner_package_sell_mumbai"
  @subscription_msg_template_pune "owner_package_sell"

  def run(_) do
    Mix.Task.run("app.start", [])
    notify_unsubscribed_brokers()
  end

  def notify_unsubscribed_brokers() do
    razorpay_subs_active_status_id = MatchPlus.get_active_status_id()
    paytm_subs_active_status_id = MatchPlusMembership.get_active_status_id()

    trigger_subs_mssg_for_unsubscribed_brokers_by_city(
      1,
      @subscription_msg_template_mumbai,
      razorpay_subs_active_status_id,
      paytm_subs_active_status_id
    )

    trigger_subs_mssg_for_unsubscribed_brokers_by_city(
      37,
      @subscription_msg_template_pune,
      razorpay_subs_active_status_id,
      paytm_subs_active_status_id
    )
  end

  def trigger_subs_mssg_for_unsubscribed_brokers_by_city(
        city_id,
        mssg_template,
        razorpay_subs_active_status_id,
        paytm_subs_active_status_id
      ) do
    brokers_with_active_subs_razorpay =
      MatchPlus
      |> join(:inner, [mp], br in Broker, on: mp.broker_id == br.id)
      |> where([_mp, br], br.operating_city == ^city_id)
      |> where([mp, _br], mp.status_id == ^razorpay_subs_active_status_id)
      |> select([mp, _br], mp.broker_id)
      |> Repo.all()

    brokers_with_active_subs_paytm =
      MatchPlusMembership
      |> join(:inner, [mp], br in Broker, on: mp.broker_id == br.id)
      |> where([_mp, br], br.operating_city == ^city_id)
      |> where([mp, _br], mp.status_id == ^paytm_subs_active_status_id)
      |> select([mp, _br], mp.broker_id)
      |> Repo.all()

    total_subscribed_brokers = brokers_with_active_subs_razorpay ++ brokers_with_active_subs_paytm
    total_subscribed_brokers = total_subscribed_brokers |> Enum.uniq()

    all_broker_ids =
      Broker
      |> join(:inner, [br], cred in Credential, on: cred.broker_id == br.id)
      |> where([br, cred], br.operating_city == ^city_id and not is_nil(cred.app_version))
      |> select([br, cred], %{
        broker_id: br.id,
        phone_number: fragment("concat(?, '', ?)", cred.country_code, cred.phone_number)
      })
      |> Repo.all()
      |> Enum.uniq_by(& &1.broker_id)
      |> Enum.uniq_by(& &1.phone_number)

    list_brokers_not_with_subscription = Enum.filter(all_broker_ids, fn broker_map -> not Enum.member?(total_subscribed_brokers, broker_map.broker_id) end)

    Enum.with_index(list_brokers_not_with_subscription)
    |> Enum.each(fn {broker_map, index} ->
      notify_broker_for_subscription(broker_map, index, city_id, mssg_template)
      Process.sleep(100)
    end)
  end

  def notify_broker_for_subscription(broker_map, index, city_id, mssg_template) do
    if not is_nil(broker_map.phone_number) do
      Exq.enqueue(
        Exq,
        "send_sms",
        BnApis.Whatsapp.SendWhatsappMessageWorker,
        [
          broker_map.phone_number,
          mssg_template
        ]
      )

      IO.puts("Index- #{index}, city_id - #{city_id}, broker_id - #{broker_map.broker_id}, phone_number - #{broker_map.phone_number}")
    end
  end
end
