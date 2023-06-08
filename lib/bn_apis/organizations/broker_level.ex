defmodule BnApis.Organizations.BrokerLevel do
  # reference BnApis.Rewards.Status
  @level_1 %{id: 1, next_rewards_lead_status_id: 1, create_rewards_lead_status_id: 8}

  def seed_data do
    [
      @level_1
    ]
  end

  def level_1, do: @level_1

  def get_by_id(id) when is_binary(id) do
    id = id |> String.to_integer()
    get_by_id(id)
  end

  def get_by_id(id) do
    seed_data()
    |> Enum.filter(&(&1.id == id))
    |> List.first()
  end
end
