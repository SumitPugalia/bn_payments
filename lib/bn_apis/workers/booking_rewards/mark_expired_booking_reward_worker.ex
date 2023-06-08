defmodule BnApis.BookingRewards.MarkExpiredBookingRewardWorker do
  import Ecto.Query

  alias BnApis.Repo
  alias BnApis.BookingRewards.Schema.BookingRewardsLead
  alias BnApis.Helpers.{ApplicationHelper, Utils, AuditedRepo}

  @expired_status_message "Brokerage invoice not raised in 90 days from approval"

  def perform() do
    channel = ApplicationHelper.get_slack_channel()

    try do
      ApplicationHelper.notify_on_slack(
        "Starting worker to mark booking rewards as expired",
        channel
      )

      cron_user_map = Utils.get_employee_user_map(%{"phone_number" => "cron", "country_code" => "+91"})

      BookingRewardsLead
      |> where([brl], brl.status_id not in [5, 7])
      |> where([brl], not is_nil(brl.approved_at))
      |> where([brl], brl.approved_at <= ^date_ninety_days_ago())
      |> preload([:invoices, :booking_payment, :booking_client])
      |> Repo.all()
      |> Enum.each(fn brl -> mark_as_expired(brl, cron_user_map) end)

      ApplicationHelper.notify_on_slack(
        "Finished marking booking rewards as expired.",
        channel
      )
    rescue
      err ->
        ApplicationHelper.notify_on_slack(
          "Error in marking booking rewards as expired: #{Exception.message(err)}",
          channel
        )
    end
  end

  def mark_as_expired(brl, cron_user_map) do
    case Enum.find(brl.invoices, fn inv -> inv.type == "brokerage" end) do
      nil -> BookingRewardsLead.changeset(brl, %{"status_id" => 7, "status_message" => @expired_status_message}) |> AuditedRepo.update(cron_user_map)
      _ -> :ok
    end
  end

  def date_ninety_days_ago() do
    NaiveDateTime.utc_now()
    |> Timex.shift(days: -90)
  end
end
