defmodule BnApis.Stories.PriorityStoriesTest do
  use BnApis.DataCase
  alias BnApis.Tests.Utils
  alias BnApis.Stories.PriorityStories
  alias BnApis.Stories.Schema.PriorityStory
  alias BnApis.Helpers.Redis

  setup_all do
    Redis.q(["FLUSHALL"])
    :ok
  end

  describe "prioritize_story/4" do
    test "succeed with required fields" do
      story = Utils.given_story()
      priority = 1
      city_id = 1
      story_id = story.id
      user_map = %{user_id: 1, user_type: "employee"}

      assert {:ok, _data} = PriorityStories.prioritize_story(story_id, city_id, priority, user_map)
    end

    test "failure with same story_id at different priority in same city" do
      story = Utils.given_story()
      priority = 1
      city_id = 1
      story_id = story.id
      user_map = %{user_id: 1, user_type: "employee"}
      {:ok, ps} = PriorityStories.prioritize_story(story_id, city_id, priority, user_map)

      priority = 2
      assert {:error, changeset} = PriorityStories.prioritize_story(story_id, city_id, priority, user_map)

      assert changeset.errors == [
               unique_active_priority_story_in_city:
                 {"An active priority story with same story_id already exists in the city.",
                  [
                    constraint: :unique,
                    constraint_name: "unique_active_priority_story_in_city_index"
                  ]}
             ]
    end

    test "failure with same priority in same city" do
      story = Utils.given_story()
      priority = 1
      city_id = 1
      story_id = story.id
      user_map = %{user_id: 1, user_type: "employee"}
      {:ok, ps} = PriorityStories.prioritize_story(story_id, city_id, priority, user_map)

      assert {:error, changeset} = PriorityStories.prioritize_story(story_id, city_id, priority, user_map)

      assert changeset.errors == [
               unique_active_priority_in_city:
                 {"An active record with same city and priority already exists.",
                  [
                    constraint: :unique,
                    constraint_name: "unique_active_priority_in_city_index"
                  ]}
             ]
    end

    test "failure with non existent story id" do
      story = Utils.given_story()
      priority = 1
      city_id = 1
      story_id = story.id + 1
      user_map = %{user_id: 1, user_type: "employee"}
      assert {:error, changeset} = PriorityStories.prioritize_story(story_id, city_id, priority, user_map)
      assert changeset.errors == [story_id: {"does not exist", [{:constraint, :foreign}, {:constraint_name, "priority_stories_story_id_fkey"}]}]
    end

    test "failure with non existent city id" do
      story = Utils.given_story()
      priority = 1
      city_id = 20
      story_id = story.id
      user_map = %{user_id: 1, user_type: "employee"}
      assert {:error, changeset} = PriorityStories.prioritize_story(story_id, city_id, priority, user_map)
      assert changeset.errors == [city_id: {"does not exist", [{:constraint, :foreign}, {:constraint_name, "priority_stories_city_id_fkey"}]}]
    end
  end

  describe "list_all_priority_stories/0" do
    test "succeed with no record present" do
      data = PriorityStories.list_all_priority_stories()
      assert is_map(data)
      assert data == %{}
    end

    test "succeed with values existing" do
      story = Utils.given_story()
      priority = 1
      city_id = 1
      story_id = story.id
      user_map = %{user_id: 1, user_type: "employee"}
      {:ok, ps} = PriorityStories.prioritize_story(story_id, city_id, priority, user_map)
      data = PriorityStories.list_all_priority_stories()
      assert is_map(data)
      assert Map.has_key?(data, Integer.to_string(city_id)) == true
    end
  end

  describe "fetch_priority_story_by_id/1" do
    test "succeed with valid id" do
      story = Utils.given_story()
      priority = 1
      city_id = 1
      story_id = story.id
      user_map = %{user_id: 1, user_type: "employee"}
      {:ok, ps} = PriorityStories.prioritize_story(story_id, city_id, priority, user_map)
      assert not is_nil(PriorityStories.fetch_priority_story_by_id(ps.id))
      assert %PriorityStory{} = PriorityStories.fetch_priority_story_by_id(ps.id)
    end

    test "fail with non existent priority_story id" do
      assert is_nil(PriorityStories.fetch_priority_story_by_id(1))
    end
  end

  describe "delete_priority_story/2" do
    test "succeed with correct id and priority_story being active" do
      story = Utils.given_story()
      priority = 1
      city_id = 1
      story_id = story.id
      user_map = %{user_id: 1, user_type: "employee"}
      {:ok, ps} = PriorityStories.prioritize_story(story_id, city_id, priority, user_map)
      assert {:ok, ps_deleted} = PriorityStories.delete_priority_story(ps.id, user_map)
      assert ps_deleted.id == ps.id
      assert ps.active == true and ps_deleted.active == false
    end

    test "fail with wrong ps_id" do
      user_map = %{user_id: 1, user_type: "employee"}
      assert {:error, :not_found} = PriorityStories.delete_priority_story(1, user_map)
    end
  end
end
