defmodule Mix.Tasks.DeduplicateCabBookingReq do
  use Mix.Task
  import Ecto.Query
  alias BnApis.Repo
  alias BnApis.Cabs.BookingRequest
  alias BnApis.Organizations.Broker
  alias BnApis.Helpers.ApplicationHelper

  @shortdoc "Deduplicate cab booking request"
  def run(_) do
    Mix.Task.run("app.start", [])
    deduplicate_cab_booking_req()
  end

  defp get_booking_req_groups() do
    Repo.all(
      from(l in BookingRequest,
        group_by: [l.broker_id, fragment("?::date", l.pickup_time), l.client_name],
        having: count(l.id) > 1,
        select: {l.broker_id, fragment("?::date", l.pickup_time), l.client_name}
      )
    )
  end

  defp get_booking_req_group_entries(broker_id, pickup_time, client_name) do
    Repo.all(
      from(l in BookingRequest,
        where: l.broker_id == ^broker_id,
        where: fragment("?::date", l.pickup_time) == ^pickup_time,
        where: l.client_name == ^client_name
      )
    )
  end

  defp deduplicate_cab_booking_req() do
    booking_req_groups = get_booking_req_groups()

    for entry <- booking_req_groups do
      broker_id = elem(entry, 0)
      pickup_time = elem(entry, 1)
      client_name = elem(entry, 2)
      booking_req_group_entries = get_booking_req_group_entries(broker_id, pickup_time, client_name)
      booking_req_group_with_index = Enum.with_index(booking_req_group_entries)

      Enum.each(booking_req_group_with_index, fn x ->
        index = elem(x, 1)
        element = elem(x, 0)

        Repo.transaction(fn ->
          try do
            if index != 0 do
              deduped_client_name = "#{element.client_name}_#{index}"

              if !is_nil(element.city_id) do
                BookingRequest.update_booking_req_for_deduping!(element, deduped_client_name, element.city_id)
              else
                # get broker city_id if city_id is null in booking req, if that too is null use Mumbai as default city
                broker_city_id = get_broker_city_id(element.broker_id)

                broker_city_id =
                  if is_nil(broker_city_id) do
                    ApplicationHelper.get_city_id_from_name("Mumbai")
                  else
                    broker_city_id
                  end

                BookingRequest.update_booking_req_for_deduping!(element, deduped_client_name, broker_city_id)
              end
            end
          rescue
            _ ->
              Repo.rollback("Unable to update cab booking request data")
          end
        end)
      end)
    end

    IO.puts("DEDUPLICATION COMPLETED")
  end

  defp get_broker_city_id(broker_id) do
    broker = Repo.get_by(Broker, id: broker_id)
    broker.operating_city
  end
end
