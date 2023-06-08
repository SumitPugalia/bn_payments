defmodule BnApis.Cabs.Status do
  @status_list %{
    1 => %{
      "identifier" => "requested",
      "display_name" => "Requested"
    },
    2 => %{
      "identifier" => "cancelled",
      "display_name" => "Cancelled"
    },
    3 => %{
      "identifier" => "driver_assigned",
      "display_name" => "Driver Assigned"
    },
    4 => %{
      "identifier" => "completed",
      "display_name" => "Completed"
    },
    5 => %{
      "identifier" => "deleted",
      "display_name" => "Deleted"
    },
    6 => %{
      "identifier" => "rerouting",
      "display_name" => "Rerouting"
    }
  }

  def status_list() do
    @status_list
  end

  def get_status_id(identifier) do
    case @status_list |> Enum.find(&(Map.get(elem(&1, 1), "identifier") == identifier)) do
      nil ->
        nil

      data ->
        data |> elem(0)
    end
  end

  # def status_details(id) do
  #   data = @status_list[id] |> Map.take(["display_name", "identifier"])
  #   Map.put(data, "id", id)
  # end

  # def get_status_filter_list(status_ids \\ []) do
  #   @status_list
  #   |> Enum.reduce([], fn {id, value}, acc ->
  #     acc ++
  #       [
  #         %{
  #           "id" => id,
  #           "display_name" => value["display_name"],
  #           "is_selected" => Enum.member?(status_ids, id)
  #         }
  #       ]
  #   end)
  # end
end
