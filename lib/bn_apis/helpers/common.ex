defmodule BnApis.Helpers.Common do
  alias BnApis.Repo
  alias BnApis.Rewards.FailureReason
  alias BnApis.Helpers.{AssignedBrokerHelper, ApplicationHelper}
  alias BnApis.Developers
  alias BnApis.Stories.Story

  def get_meta_data() do
    fail_reason = %{
      "failure_reason" => FailureReason.failure_reason_list(),
      "support_number" => ApplicationHelper.get_mumbai_customer_support_number()
    }

    {:ok, fail_reason}
  end

  def search_entities_for_employee(logged_in_user, query, entity_type) do
    if is_nil(query) or query == "" do
      {:ok, []}
    else
      query = query |> String.downcase()
      entity_type = entity_type |> String.downcase()
      search_any = is_nil(entity_type) or entity_type == "any"
      search_broker = search_any or entity_type == "broker"
      search_project = search_any or entity_type == "project"
      search_developer = search_any or entity_type == "developer"

      broker_suggestions =
        if(search_broker, do: AssignedBrokerHelper.search_assigned_broker(logged_in_user.user_id, query), else: [])
        |> Enum.map(fn item ->
          item |> Map.put(:entity_type, "broker")
        end)

      project_suggestions =
        if(search_project, do: Story.search_story_query(query, logged_in_user.city_id, [], %{}) |> Repo.all(), else: [])
        |> Enum.map(fn item ->
          %{
            id: item.id,
            name: item.name,
            entity_type: "project"
          }
        end)

      developer_suggestions =
        if(search_developer, do: Developers.get_developer_suggestions(query, []), else: [])
        |> Enum.map(fn item ->
          item |> Map.put(:entity_type, "developer")
        end)

      {:ok, broker_suggestions ++ project_suggestions ++ developer_suggestions}
    end
  end
end
