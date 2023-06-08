defmodule BnApis.Cabs.MarkBookingRequestsAsCompletedWorker do
  import Ecto.Query

  alias BnApis.Repo
  alias BnApis.Cabs
  alias BnApis.Cabs.BookingRequest
  alias BnApis.Cabs.Status
  alias BnApis.Helpers.ApplicationHelper

  def perform() do
    mark_booking_requests_as_completed()
  end

  defp mark_booking_requests_as_completed() do
    today = Timex.now() |> Timex.Timezone.convert("Asia/Kolkata")
    previous_day = today
    beginning_of_preivous_day = Timex.beginning_of_day(previous_day)
    end_of_preivous_day = Timex.end_of_day(previous_day)

    previous_day_bookings =
      BookingRequest
      |> where([b], b.status_id == ^Status.get_status_id("driver_assigned"))
      |> where([b], b.pickup_time >= ^beginning_of_preivous_day)
      |> where([b], b.pickup_time <= ^end_of_preivous_day)
      |> Repo.all()

    channel = ApplicationHelper.get_slack_channel()

    ApplicationHelper.notify_on_slack(
      "Starting to mark bookings as completed",
      channel
    )

    # TODO mark rerouting requests as cancelled

    Enum.each(previous_day_bookings, fn booking_request ->
      try do
        Cabs.mark_completed(%{"id" => booking_request.id}, %{})
      rescue
        _ ->
          ApplicationHelper.notify_on_slack(
            "Error in auto marking booking request as completed with id: #{booking_request.id}",
            channel
          )
      end
    end)
  end
end
