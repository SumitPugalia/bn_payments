defmodule BnApis.BookingRewards.Status do
  @valid_status_list %{
    "incomplete" => 0,
    "draft" => 1,
    "pending" => 2,
    "changes_requested" => 3,
    "approved_by_bn" => 4,
    "rejected_by_bn" => 5,
    "paid" => 6,
    "expired" => 7,
    "approved_by_finance" => 8,
    "rejected_by_finance" => 9,
    "approved_by_crm" => 10,
    "rejected_by_crm" => 11
  }

  @valid_status_change %{
    nil => ["incomplete", "draft", "pending"],
    "incomplete" => ["draft", "pending"],
    "draft" => ["pending"],
    "pending" => ["changes_requested", "approved_by_bn", "rejected_by_bn"],
    "changes_requested" => ["pending", "approved_by_bn", "rejected_by_bn"],
    "approved_by_bn" => ["approved_by_finance", "rejected_by_finance", "expired", "changes_requested"],
    "approved_by_finance" => ["approved_by_crm", "rejected_by_crm", "expired", "changes_requested"],
    "approved_by_crm" => ["paid", "expired"],
    "rejected_by_bn" => [],
    "rejected_by_finance" => [],
    "rejected_by_crm" => [],
    "paid" => ["expired"],
    "expired" => []
  }

  def valid_status_change(status), do: @valid_status_change[status]

  def get_status_id!(status), do: Map.fetch!(@valid_status_list, status)

  def get_status_from_id(id) do
    Enum.find(@valid_status_list, fn {_key, value} -> value == id end)
    |> case do
      nil -> throw(:invalid_status_id)
      {key, _value} -> key
    end
  end

  def get_status_filter_list(status_ids) do
    Enum.reduce(@valid_status_list, [], fn {key, val}, acc ->
      data = %{
        "id" => val,
        "display_name" => key,
        "is_selected" => Enum.member?(status_ids, val)
      }

      acc ++ [data]
    end)
  end

  def ids(), do: Enum.map(@valid_status_list, fn {_k, v} -> v end)
  def names(), do: Map.keys(@valid_status_list)
end
