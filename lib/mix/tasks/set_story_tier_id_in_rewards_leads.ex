defmodule Mix.Tasks.SetStoryTierIdInRewardsLeads do
  use Mix.Task
  import Ecto.Query

  alias BnApis.Repo
  alias BnApis.Rewards.RewardsLead

  @shortdoc "set story tier id as 1 for null values in rewards leads"
  def run(_) do
    Mix.Task.run("app.start", [])
    update_rewards_leads()
  end

  defp update_rewards_leads() do
    Repo.transaction(
      fn ->
        from(rl in RewardsLead)
        |> Repo.stream()
        |> Stream.each(fn data -> update_story_tier_id_if_null(data.story_tier_id, data) end)
        |> Stream.run()
      end,
      timeout: :infinity
    )
  end

  defp update_story_tier_id_if_null(nil, lead) do
    try do
      RewardsLead.changeset(lead, %{"story_tier_id" => 1})
      |> Repo.update()
    rescue
      error -> error
    end
  end

  defp update_story_tier_id_if_null(_, _lead), do: nil
end
