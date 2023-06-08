defmodule BnApis.Workers.Stories.RewardsActivatedWeeklyNotificationWorkerTest do
  import Ecto.Query
  use BnApis.DataCase

  alias BnApis.Tests.Utils
  alias BnApis.Stories.Story
  alias BnApis.Stories
  alias BnApis.Projects.RewardsActivatedWeeklyNotificationWorker
  alias BnApis.Log
  alias BnApis.Helpers.Redis
  alias BnApis.Factory

  setup_all do
    Redis.q(["FLUSHALL"])
    :ok
  end

  describe "get_sv_rewards_activated_story_list/1" do
    test "success when there is no sv_rewards activated" do
      {starting_interval, ending_interval} = RewardsActivatedWeeklyNotificationWorker.get_time_interval()

      query =
        Log
        |> where([l], l.entity_type == "stories" and l.inserted_at >= ^starting_interval and l.inserted_at < ^ending_interval)
        |> join(:inner, [l], st in Story, on: l.entity_id == st.id)

      story_map = RewardsActivatedWeeklyNotificationWorker.get_sv_rewards_activated_story_list(query)
      assert story_map == []
    end

    test "success where there is sv_rewards activated" do
      old_timestamp = Timex.now() |> Timex.shift(days: -3) |> Timex.to_naive_datetime() |> NaiveDateTime.truncate(:second)
      cred = Factory.insert(:credential)
      st = Utils.given_story(cred)
      {:ok, st} = Stories.update_story(st, %{"is_rewards_enabled" => true}, %{user_id: 1, user_type: "update_employee"})
      l = Log |> Repo.get_by(entity_id: st.id, entity_type: "stories", user_type: "update_employee")
      ch = l |> change(inserted_at: old_timestamp, updated_at: old_timestamp) |> Repo.update()
      {starting_interval, ending_interval} = RewardsActivatedWeeklyNotificationWorker.get_time_interval()

      query =
        Log
        |> where([l], l.entity_type == "stories" and l.inserted_at >= ^starting_interval and l.inserted_at < ^ending_interval)
        |> join(:inner, [l], st in Story, on: l.entity_id == st.id)

      story_map = RewardsActivatedWeeklyNotificationWorker.get_sv_rewards_activated_story_list(query)
      assert story_map == [%{story_name: st.name, operating_cities: st.operating_cities}]
    end
  end

  describe "get_booking_rewards_activated_story_list/1" do
    test "success when there is no booking_rewards activated" do
      {starting_interval, ending_interval} = RewardsActivatedWeeklyNotificationWorker.get_time_interval()

      query =
        Log
        |> where([l], l.entity_type == "stories" and l.inserted_at >= ^starting_interval and l.inserted_at < ^ending_interval)
        |> join(:inner, [l], st in Story, on: l.entity_id == st.id)

      story_map = RewardsActivatedWeeklyNotificationWorker.get_booking_rewards_activated_story_list(query)
      assert story_map == []
    end

    test "success where there is booking_rewards activated" do
      old_timestamp = Timex.now() |> Timex.shift(days: -3) |> Timex.to_naive_datetime() |> NaiveDateTime.truncate(:second)
      cred = Factory.insert(:credential)
      st = Utils.given_story(cred)
      {:ok, st} = Stories.update_story(st, %{"is_booking_reward_enabled" => true}, %{user_id: 1, user_type: "update_employee"})
      l = Log |> Repo.get_by(entity_id: st.id, entity_type: "stories", user_type: "update_employee")
      ch = l |> change(inserted_at: old_timestamp, updated_at: old_timestamp) |> Repo.update()
      {starting_interval, ending_interval} = RewardsActivatedWeeklyNotificationWorker.get_time_interval()

      query =
        Log
        |> where([l], l.entity_type == "stories" and l.inserted_at >= ^starting_interval and l.inserted_at < ^ending_interval)
        |> join(:inner, [l], st in Story, on: l.entity_id == st.id)

      story_map = RewardsActivatedWeeklyNotificationWorker.get_booking_rewards_activated_story_list(query)
      assert story_map == [%{story_name: st.name, operating_cities: st.operating_cities}]
    end
  end

  describe "generate_city_wise_story_lists/2" do
    test "success when neither sv rewards nor booking rewards is enabled" do
      {sv_map, br_map} = RewardsActivatedWeeklyNotificationWorker.generate_city_wise_story_lists([], [])
      assert sv_map = %{1 => "", 2 => "", 3 => "", 37 => ""}
      assert br_map = %{1 => "", 2 => "", 3 => "", 37 => ""}
    end

    test "success when sv rewards enabled but booking rewards is not enabled" do
      old_timestamp = Timex.now() |> Timex.shift(days: -3) |> Timex.to_naive_datetime() |> NaiveDateTime.truncate(:second)
      cred = Factory.insert(:credential)
      st = Utils.given_story(cred)
      {:ok, st} = Stories.update_story(st, %{"is_rewards_enabled" => true}, %{user_id: 1, user_type: "update_employee"})
      l = Log |> Repo.get_by(entity_id: st.id, entity_type: "stories", user_type: "update_employee")
      ch = l |> change(inserted_at: old_timestamp, updated_at: old_timestamp) |> Repo.update()
      {starting_interval, ending_interval} = RewardsActivatedWeeklyNotificationWorker.get_time_interval()

      query =
        Log
        |> where([l], l.entity_type == "stories" and l.inserted_at >= ^starting_interval and l.inserted_at < ^ending_interval)
        |> join(:inner, [l], st in Story, on: l.entity_id == st.id)

      story_map = RewardsActivatedWeeklyNotificationWorker.get_sv_rewards_activated_story_list(query)
      {sv_map, br_map} = RewardsActivatedWeeklyNotificationWorker.generate_city_wise_story_lists(story_map, [])

      for city_id <- st.operating_cities do
        assert sv_map[city_id] == st.name
      end

      assert br_map = %{1 => "", 2 => "", 3 => "", 37 => ""}
    end

    test "success when sv rewards is not enabled but booking rewards is enabled" do
      old_timestamp = Timex.now() |> Timex.shift(days: -3) |> Timex.to_naive_datetime() |> NaiveDateTime.truncate(:second)
      cred = Factory.insert(:credential)
      st = Utils.given_story(cred)
      {:ok, st} = Stories.update_story(st, %{"is_booking_reward_enabled" => true}, %{user_id: 1, user_type: "update_employee"})
      l = Log |> Repo.get_by(entity_id: st.id, entity_type: "stories", user_type: "update_employee")
      ch = l |> change(inserted_at: old_timestamp, updated_at: old_timestamp) |> Repo.update()
      {starting_interval, ending_interval} = RewardsActivatedWeeklyNotificationWorker.get_time_interval()

      query =
        Log
        |> where([l], l.entity_type == "stories" and l.inserted_at >= ^starting_interval and l.inserted_at < ^ending_interval)
        |> join(:inner, [l], st in Story, on: l.entity_id == st.id)

      story_map = RewardsActivatedWeeklyNotificationWorker.get_booking_rewards_activated_story_list(query)
      {sv_map, br_map} = RewardsActivatedWeeklyNotificationWorker.generate_city_wise_story_lists([], story_map)

      for city_id <- st.operating_cities do
        assert br_map[city_id] == st.name
      end

      assert sv_map = %{1 => "", 2 => "", 3 => "", 37 => ""}
    end

    test "success when both sv rewards and booking rewards is enabled" do
      old_timestamp = Timex.now() |> Timex.shift(days: -3) |> Timex.to_naive_datetime() |> NaiveDateTime.truncate(:second)
      cred = Factory.insert(:credential)
      st = Utils.given_story(cred)
      {:ok, st} = Stories.update_story(st, %{"is_rewards_enabled" => true, "is_booking_reward_enabled" => true}, %{user_id: 1, user_type: "update_employee"})
      l = Log |> Repo.get_by(entity_id: st.id, entity_type: "stories", user_type: "update_employee")
      ch = l |> change(inserted_at: old_timestamp, updated_at: old_timestamp) |> Repo.update()
      {starting_interval, ending_interval} = RewardsActivatedWeeklyNotificationWorker.get_time_interval()

      query =
        Log
        |> where([l], l.entity_type == "stories" and l.inserted_at >= ^starting_interval and l.inserted_at < ^ending_interval)
        |> join(:inner, [l], st in Story, on: l.entity_id == st.id)

      sv_story_map = RewardsActivatedWeeklyNotificationWorker.get_sv_rewards_activated_story_list(query)
      br_story_map = RewardsActivatedWeeklyNotificationWorker.get_booking_rewards_activated_story_list(query)
      {sv_map, br_map} = RewardsActivatedWeeklyNotificationWorker.generate_city_wise_story_lists(sv_story_map, br_story_map)

      for city_id <- st.operating_cities do
        assert sv_map[city_id] == st.name
        assert br_map[city_id] == st.name
      end
    end
  end
end
