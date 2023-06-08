defmodule BnApis.Rewards.Status do
  @status_list %{
    1 => %{
      "identifier" => "pending",
      "display_name" => "Pending"
    },
    2 => %{
      "identifier" => "rejected",
      "display_name" => "Rejected"
    },
    3 => %{
      "identifier" => "approved",
      "display_name" => "Approved"
    },
    4 => %{
      "identifier" => "reward_received",
      "display_name" => "Reward Received"
    },
    5 => %{
      "identifier" => "employee_reward_received",
      "display_name" => "Employee Reward Received"
    },
    6 => %{
      "identifier" => "draft",
      "display_name" => "Draft"
    },
    7 => %{
      "identifier" => "deleted",
      "display_name" => "Deleted"
    },
    8 => %{
      "identifier" => "in_review",
      "display_name" => "In Review"
    },
    9 => %{
      "identifier" => "rejected_by_manager",
      "display_name" => "Rejected By Manager"
    }
  }

  @valid_status_change %{
    nil => ["draft", "in_review", "pending"],
    "draft" => ["in_review", "deleted"],
    "in_review" => ["pending", "rejected_by_manager"],
    "pending" => ["approved", "rejected"],
    "rejected_by_manager" => ["pending"],
    "approved" => ["reward_received", "employee_reward_received"],
    "rejected" => ["approved"],
    "deleted" => [],
    "reward_received" => ["employee_reward_received"],
    "employee_reward_received" => ["reward_received"]
  }

  def valid_status_change(status), do: @valid_status_change[status]

  def get_status_from_id(status_id), do: get_in(@status_list, [status_id, "identifier"])

  def status_list() do
    @status_list
  end

  def status_details(id) do
    data = @status_list[id] |> Map.take(["display_name", "identifier"])
    Map.put(data, "id", id)
  end

  def get_status_filter_list(status_ids \\ []) do
    @status_list
    |> Enum.reduce([], fn {id, value}, acc ->
      acc ++
        [
          %{
            "id" => id,
            "display_name" => value["display_name"],
            "is_selected" => Enum.member?(status_ids, id)
          }
        ]
    end)
  end

  def get_status_id(identifier) do
    case @status_list |> Enum.find(&(Map.get(elem(&1, 1), "identifier") == identifier)) do
      nil ->
        nil

      data ->
        data |> elem(0)
    end
  end
end
