defmodule BnApis.Stories.PriorityStories do
  import Ecto.Query

  alias BnApis.Repo
  alias BnApis.Stories.Schema.PriorityStory
  alias BnApis.Helpers.AuditedRepo
  alias BnApis.Stories.Story
  alias BnApis.Developers.Developer
  alias BnApis.Places.City

  def prioritize_story(story_id, city_id, priority, user_map) do
    PriorityStory.changeset(%PriorityStory{}, %{"story_id" => story_id, "city_id" => city_id, "priority" => priority})
    |> AuditedRepo.insert(user_map)
  end

  def list_all_priority_stories() do
    PriorityStory
    |> join(:inner, [ps], s in Story, on: ps.story_id == s.id)
    |> join(:inner, [ps, s], dev in Developer, on: s.developer_id == dev.id)
    |> join(:inner, [ps, s, dev], c in City, on: ps.city_id == c.id)
    |> where([ps], ps.active == true)
    |> order_by([ps], asc: ps.city_id, desc: ps.priority)
    |> select([ps, s, dev, c], %{
      "id" => ps.id,
      "story_id" => ps.story_id,
      "story_name" => s.name,
      "story_uuid" => s.uuid,
      "story_image_url" => s.image_url,
      "developer_name" => dev.name,
      "city_id" => ps.city_id,
      "city_name" => c.name,
      "priority" => ps.priority
    })
    |> Repo.all()
  end

  def fetch_priority_story_by_id(id) do
    PriorityStory
    |> where([ps], ps.id == ^id and ps.active == true)
    |> Repo.one()
  end

  def delete_priority_story(id, user_map) do
    case fetch_priority_story_by_id(id) do
      nil -> {:error, :not_found}
      ps -> PriorityStory.changeset(ps, %{"active" => false}) |> AuditedRepo.update(user_map)
    end
  end

  def change_priority_story(priority_story_id, new_story_id, user_map) do
    Repo.transaction(fn ->
      with {:ok, old_ps} <- delete_priority_story(priority_story_id, user_map),
           {:ok, new_ps} <- prioritize_story(new_story_id, old_ps.city_id, old_ps.priority, user_map) do
        new_ps
      else
        {:error, reason} -> Repo.rollback(reason)
      end
    end)
  end
end
