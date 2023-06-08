defmodule Mix.Tasks.DeduplicateRewardsLead do
  use Mix.Task
  import Ecto.Query
  alias BnApis.Repo
  alias BnApis.Rewards.RewardsLead

  @shortdoc "Deduplicate Rewards Lead data"
  def run(_) do
    Mix.Task.run("app.start", [])
    deduplicate_rewards_lead_data()
  end

  defp get_reward_lead_groups() do
    Repo.all(
      from(l in RewardsLead,
        group_by: [
          l.broker_id,
          l.story_id,
          l.name,
          fragment("CASE WHEN ? IS NULL THEN ?::date ELSE ?::date END", l.visit_date, l.inserted_at, l.visit_date)
        ],
        having: count(l.id) > 1,
        select: {l.broker_id, l.story_id, l.name, fragment("CASE WHEN ? IS NULL THEN ?::date ELSE ?::date END", l.visit_date, l.inserted_at, l.visit_date), count(l.id)}
      )
    )
  end

  defp get_reward_lead_group_entries(broker_id, story_id, client_name, visit_date) do
    Repo.all(
      from(l in RewardsLead,
        where: l.broker_id == ^broker_id,
        where: l.story_id == ^story_id,
        where: l.name == ^client_name,
        where:
          fragment("CASE WHEN ? IS NULL THEN ?::date ELSE ?::date END", l.visit_date, l.inserted_at, l.visit_date) ==
            ^visit_date
      )
    )
  end

  defp get_group_developer_poc_credential_id(reward_lead_group_entries) do
    lead = Enum.find(reward_lead_group_entries, fn entry -> not is_nil(entry.developer_poc_credential_id) end)
    if not is_nil(lead), do: lead.developer_poc_credential_id, else: nil
  end

  defp get_developer_poc_credential_id_based_on_story_id(story_id) do
    lead =
      Repo.one(
        from(lead in RewardsLead,
          where: lead.story_id == ^story_id,
          where: not is_nil(lead.developer_poc_credential_id),
          limit: 1
        )
      )

    lead.developer_poc_credential_id
  end

  defp deduplicate_rewards_lead_data() do
    IO.puts("STARTING THE DEDUPLICATION OF NAMES")
    # Record Lead Group Format: {broker_id, story_id, name, visit_date, count}
    reward_lead_groups = get_reward_lead_groups()
    IO.puts("NUMBER OF GROUPS TO BE DEDUPLICATES: #{length(reward_lead_groups)}")

    for entry <- reward_lead_groups do
      b_id = elem(entry, 0)
      s_id = elem(entry, 1)
      client_name = elem(entry, 2)
      client_visit_date = elem(entry, 3)
      # count = elem(entry, 4)

      reward_lead_group_entries = get_reward_lead_group_entries(b_id, s_id, client_name, client_visit_date)
      ## Get Group Developer Poc Credential ID
      group_developer_poc_credential_id = get_group_developer_poc_credential_id(reward_lead_group_entries)

      # If Group Developer Poc Credential ID, fetch POC ID from repository based on Story ID
      default_developer_poc_credential_id =
        if is_nil(group_developer_poc_credential_id) do
          get_developer_poc_credential_id_based_on_story_id(s_id)
        else
          group_developer_poc_credential_id
        end

      for counter <- 0..(length(reward_lead_group_entries) - 1) do
        reward_lead = Enum.at(reward_lead_group_entries, counter)

        Repo.transaction(fn ->
          try do
            developer_poc_credential_id =
              if is_nil(reward_lead.developer_poc_credential_id) do
                default_developer_poc_credential_id
              else
                reward_lead.developer_poc_credential_id
              end

            deduped_client_name =
              if counter != 0 do
                "#{reward_lead.name}_#{counter}"
              else
                reward_lead.name
              end

            RewardsLead.update_rewards_lead_for_deduping!(reward_lead, deduped_client_name, developer_poc_credential_id)
          rescue
            _ ->
              Repo.rollback("Unable to update rewards lead data")
          end
        end)
      end
    end

    IO.puts("DEDUPLICATION COMPLETE")
  end
end
