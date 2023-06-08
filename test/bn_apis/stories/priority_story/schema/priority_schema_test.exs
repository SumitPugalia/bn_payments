defmodule BnApis.Stories.PriorityStory.Schema.PriorityStoryTest do
  use BnApis.DataCase
  alias BnApis.Stories.Schema.PriorityStory

  @valid_params %{
    "story_id" => 1,
    "city_id" => 1,
    "priority" => 1
  }

  describe "priority_story changeset/2" do
    @required_fields ["story_id", "city_id", "priority"]

    test "succeed with required fields without default field" do
      story_id = @valid_params["story_id"]
      city_id = @valid_params["city_id"]
      priority = @valid_params["priority"]

      assert %Ecto.Changeset{changes: %{story_id: ^story_id, city_id: ^city_id, priority: ^priority}, valid?: true} = PriorityStory.changeset(%PriorityStory{}, @valid_params)
    end

    test "succeed with required fields with default field" do
      story_id = @valid_params["story_id"]
      city_id = @valid_params["city_id"]
      priority = @valid_params["priority"]
      valid_params = Map.put(@valid_params, "active", true)
      active = true

      assert %Ecto.Changeset{changes: %{story_id: ^story_id, city_id: city_id, priority: priority}, valid?: true} = PriorityStory.changeset(%PriorityStory{}, valid_params)
    end

    test "succeed with required fields with active false" do
      story_id = @valid_params["story_id"]
      city_id = @valid_params["city_id"]
      priority = @valid_params["priority"]
      valid_params = Map.put(@valid_params, "active", false)
      active = true

      assert %Ecto.Changeset{changes: %{story_id: ^story_id, city_id: city_id, priority: priority, active: false}, valid?: true} =
               PriorityStory.changeset(%PriorityStory{}, valid_params)
    end

    test "failure without required fields" do
      for {key, _} <- @valid_params |> Map.take(@required_fields) do
        invalid_params = @valid_params |> Map.delete(key)
        %Ecto.Changeset{errors: errors, valid?: false} = PriorityStory.changeset(%PriorityStory{}, invalid_params)

        assert errors == [
                 {String.to_existing_atom(key), {"can't be blank", [validation: :required]}}
               ]
      end
    end

    test "fails with invalid type" do
      for {key, _} <- @valid_params |> Map.take(@required_fields -- ["priority"]) do
        invalid_params = @valid_params |> Map.put(key, "invalid_id")
        %Ecto.Changeset{errors: errors, valid?: false} = PriorityStory.changeset(%PriorityStory{}, invalid_params)

        assert errors == [
                 {String.to_existing_atom(key), {"is invalid", [type: :id, validation: :cast]}}
               ]
      end

      invalid_params = @valid_params |> Map.put("priority", "hello")
      %Ecto.Changeset{errors: errors, valid?: false} = PriorityStory.changeset(%PriorityStory{}, invalid_params)

      assert errors == [
               {:priority, {"is invalid", [type: :integer, validation: :cast]}}
             ]

      invalid_params = @valid_params |> Map.put("active", "hello")
      %Ecto.Changeset{errors: errors, valid?: false} = PriorityStory.changeset(%PriorityStory{}, invalid_params)

      assert errors == [
               {:active, {"is invalid", [type: :boolean, validation: :cast]}}
             ]
    end

    test "fails with invalid value at priority" do
      invalid_params = @valid_params |> Map.put("priority", 4)
      %Ecto.Changeset{errors: errors, valid?: false} = PriorityStory.changeset(%PriorityStory{}, invalid_params)

      assert errors == [
               {:priority, {"is invalid", [validation: :inclusion, enum: [1, 2, 3]]}}
             ]
    end
  end
end
