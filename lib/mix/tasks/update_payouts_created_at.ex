defmodule Mix.Tasks.UpdatePayoutsCreatedAt do
  use Mix.Task
  import Ecto.Query

  alias BnApis.Helpers.ApplicationHelper
  alias BnApis.Helpers.ExternalApiHelper
  alias BnApis.Rewards.Payout
  alias BnApis.Repo

  @shortdoc "update payouts created at"
  def run(_) do
    Mix.Task.run("app.start", [])
    update_payouts()
  end

  defp update_payouts() do
    channel = ApplicationHelper.get_slack_channel()

    ApplicationHelper.notify_on_slack(
      "Starting to update payouts",
      channel
    )

    Payout
    |> where([p], is_nil(p.created_at))
    |> order_by([p], asc: p.id)
    |> Repo.all()
    |> Enum.each(fn payout ->
      try do
        update_payout(payout)
      rescue
        _ ->
          ApplicationHelper.notify_on_slack(
            "Error in updating payout with id: #{payout.id}",
            channel
          )
      end
    end)

    ApplicationHelper.notify_on_slack(
      "Finished to update payouts",
      channel
    )
  end

  defp update_payout(payout) do
    params = fetch_razorpay_payout_details(payout.payout_id)

    if not is_nil(params["created_at"]) do
      ch =
        Payout.changeset(payout, %{
          created_at: params["created_at"]
        })

      Repo.update!(ch)
      IO.puts("updating payout with id: #{payout.id}")
    else
      IO.puts("created_at param is nil for payout with id: #{payout.id}")
    end
  end

  defp fetch_razorpay_payout_details(razorpay_payout_id) do
    auth_key = ApplicationHelper.get_razorpay_auth_key()

    {_status_code, response} =
      ExternalApiHelper.get_razorpay_payout_details(
        razorpay_payout_id,
        auth_key
      )

    response
  end
end
