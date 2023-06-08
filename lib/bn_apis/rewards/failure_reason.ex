defmodule BnApis.Rewards.FailureReason do
  @failure_reason_list [
    %{
      "id" => 0,
      "identifier" => "not_valid_visit",
      "display_name" => "Customer visited, but rejecting",
      :status => "Active"
    },
    %{
      "id" => 1,
      "identifier" => "not_genuine_vist",
      "display_name" => "Customer did not visit",
      :status => "Active"
    },
    %{
      "id" => 2,
      "identifier" => "not_fresh_visit",
      "display_name" => "Customer revisited",
      :status => "Active"
    },
    %{
      "id" => 3,
      "identifier" => "unregistered_broker",
      "display_name" => "Not a registered broker/ NO RERA",
      :status => "Inactive"
    },
    %{
      "id" => 4,
      "identifier" => "direct_client",
      "display_name" => "Direct Client/ Mis representation",
      :status => "Inactive"
    },
    %{
      "id" => 5,
      "identifier" => "other",
      "display_name" => "Other",
      :status => "Inactive"
    }
  ]

  def failure_reason_list() do
    @failure_reason_list
    |> Enum.filter(&(&1.status == "Active"))
  end

  def failure_reason_details(nil) do
    nil
  end

  def failure_reason_details(id) do
    reason = @failure_reason_list |> Enum.find(fn x -> Map.get(x, "id") == id end)

    if is_nil(reason) do
      %{
        "id" => id,
        "identifier" => "other",
        "display_name" => "Other"
      }
    else
      data = reason |> Map.take(["display_name", "identifier"])
      Map.put(data, "id", id)
    end
  end
end
