defmodule BnApis.Dashboard.Ecto do
  def log(measurements) do
    case measurements do
      %{queue_time: queue} when is_integer(queue) ->
        Appsignal.add_distribution_value("ecto.queue_time", millisecond(queue))

      _ ->
        nil
    end

    case measurements do
      %{idle_time: idle} when is_integer(idle) ->
        Appsignal.add_distribution_value("ecto.idle_time", millisecond(idle))

      _ ->
        nil
    end

    case measurements do
      %{query_time: query} when is_integer(query) ->
        Appsignal.add_distribution_value("ecto.query_time", millisecond(query))

      _ ->
        nil
    end

    case measurements do
      %{decode_time: decode} when is_integer(decode) ->
        Appsignal.add_distribution_value("ecto.decode_time", millisecond(decode))

      _ ->
        nil
    end
  end

  def handle_event([:bn_apis, :repo, :query], measurements, _metadata, _config), do: log(measurements)

  defp millisecond(time), do: System.convert_time_unit(time, :native, :millisecond)
end
