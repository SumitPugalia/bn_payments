defmodule BnApis.Cabs.DiscardReroutingRequest do
  import Ecto.Query

  alias BnApis.Repo
  alias BnApis.Cabs.BookingRequest
  alias BnApis.Cabs.Status
  alias BnApis.Helpers.ApplicationHelper
  alias BnApis.Cabs.Vehicle

  def perform() do
    channel = ApplicationHelper.get_slack_channel()

    ApplicationHelper.notify_on_slack(
      "Started Automatically cancelled booking via cron ",
      channel
    )

    discard_rerouting_booking()

    ApplicationHelper.notify_on_slack(
      "Finished Automatically cancelled booking via cron",
      channel
    )
  end

  defp discard_rerouting_booking do
    today = Timex.now() |> Timex.Timezone.convert("Asia/Kolkata")
    previous_day = today
    beginning_of_the_day = Timex.beginning_of_day(previous_day)
    current_time = Timex.end_of_day(previous_day)

    BookingRequest
    |> where([b], b.pickup_time >= ^beginning_of_the_day)
    |> where([b], b.pickup_time <= ^current_time)
    |> where([b], b.status_id == ^Status.get_status_id("rerouting"))
    |> Repo.all()
    |> Enum.each(fn request ->
      BookingRequest.cancel_booking_request!(request, nil, "Automatically cancelled via cron", false)
    end)

    Vehicle
    |> where([v], v.is_available_for_rerouting == ^true)
    |> Repo.all()
    |> Enum.each(fn vehicle ->
      Vehicle.assign(vehicle.id, false, false)
    end)
  end
end
