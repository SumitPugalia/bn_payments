defmodule Mix.Tasks.UpdateStoryTierForAacronProject do
  use Mix.Task

  alias BnApis.Repo
  alias BnApis.Rewards.RewardsLead
  alias BnApis.Rewards.StoryTier

  @path ["rewards_story_tier_plan_22_09.csv"]

  @shortdoc "Update story-tier_id for Reward leads"
  def run(_) do
    Mix.Task.run("app.start", [])

    IO.puts("STARTING THE UPDATE TASK")
    # remove first line from csv file that contains headers
    @path
    |> Enum.each(&update/1)

    IO.puts("UPDATE TASK COMPLETE")
  end

  def update(path) do
    File.stream!("#{File.cwd!()}/priv/data/#{path}")
    |> CSV.decode()
    |> Enum.to_list()
    |> Enum.map(&update_rewards/1)
  end

  def update_rewards({:error, data}) do
    IO.inspect("========== Error: ============")
    IO.inspect(data)
    nil
  end

  def update_rewards({:ok, data}) do
    # Extract data from CSV
    rewards_lead_id = Enum.at(data, 0)
    story_tier_id = Enum.at(data, 2)

    rewards_lead = get_rewards_lead_from_repo(rewards_lead_id)
    story_tier = get_story_tier_from_repo(story_tier_id)

    case {rewards_lead, story_tier} do
      {nil, _} ->
        IO.inspect("============== Invalid:  =============")
        IO.inspect("Rewards Lead: #{rewards_lead_id} not found.")

      {_, nil} ->
        IO.inspect("============== Invalid:  =============")
        IO.inspect("Invalid Story tier Id: #{story_tier_id}")

      {rewards_lead, story_tier} ->
        RewardsLead.update_story_tier_for_rewards_lead(rewards_lead, story_tier.id)
        |> case do
          {:ok, rewards_lead} ->
            IO.inspect("Rewards Lead: #{rewards_lead.id} updated with Story Tier Id: #{story_tier.id}")

          {:error, error} ->
            IO.inspect("============== Error:  =============")

            IO.inspect("Issue while updating record with Rewards Lead Id: #{rewards_lead_id} and Story Tier Id: #{story_tier_id}.")

            IO.inspect(error)
        end
    end
  end

  defp get_rewards_lead_from_repo(nil), do: nil
  defp get_rewards_lead_from_repo(rewards_lead_id), do: RewardsLead |> Repo.get(rewards_lead_id)

  defp get_story_tier_from_repo(nil), do: nil
  defp get_story_tier_from_repo(story_tier_id), do: StoryTier |> Repo.get(story_tier_id)
end
