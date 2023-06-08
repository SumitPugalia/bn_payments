defmodule BnApis.Subscriptions.UpdateUserPackageStatusWorker do
  alias BnApis.Packages
  alias BnApis.Helpers.ApplicationHelper

  def perform() do
    channel = ApplicationHelper.get_slack_channel()
    last_created_at = Timex.now() |> Timex.shift(minutes: -30) |> Timex.Timezone.convert("Asia/Kolkata") |> DateTime.to_unix()
    ApplicationHelper.notify_on_slack("Started updating status for user package", channel)

    %{status: :created, last_created_at: last_created_at}
    |> Packages.get_all_user_order_by()
    |> Enum.each(fn user_order ->
      ApplicationHelper.notify_on_slack("Started updating status for user package with order_id #{user_order.id}", channel)

      user_order = Packages.get_user_order_by(%{id: user_order.id}, [:user_packages, :payments])
      payment = user_order.payments |> Enum.sort(&(&1.inserted_at > &2.inserted_at)) |> List.first()

      case user_order.id |> BnPayments.Requests.get_transaction_payload_by_order_id() |> BnPayments.get_transaction() do
        {:ok, txn} ->
          ApplicationHelper.notify_on_slack("Found order_id #{user_order.id} to be updated in Billdesk", channel)
          Packages.update_payment_from_txn(txn, payment, true)

        {:error, status_code, error} when status_code in [404, "404"] ->
          ApplicationHelper.notify_on_slack("ABORTING order_id #{user_order.id} with status: #{status_code} with error: #{inspect(error)}", channel)

          Packages.update_user_order(user_order, %{
            status: :aborted,
            user_packages: updated_user_packages(user_order.user_packages, %{status: :aborted})
          })

        {:error, status_code, error} ->
          ApplicationHelper.notify_on_slack("Error for order_id #{user_order.id} with status: #{status_code} with error: #{inspect(error)}", channel)
      end
    end)

    ApplicationHelper.notify_on_slack(
      "Finished updating status for user package",
      channel
    )
  end

  defp updated_user_packages(user_packages, params) do
    user_packages
    |> Enum.reduce([], fn user_package, acc ->
      [user_package |> Map.from_struct() |> Map.merge(params) | acc]
    end)
  end
end
