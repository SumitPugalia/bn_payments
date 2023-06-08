defmodule Mix.Tasks.EnableBookingRewards do
  use Mix.Task

  alias BnApis.Stories
  alias BnApis.Helpers.Utils
  alias BnApis.Stories.Story

  @path ["enable_booking_rewards_09_11_22.csv"]

  @shortdoc "Enable booking rewards for stories"
  def run(_) do
    Mix.Task.run("app.start", [])

    IO.puts("STARTING THE TASK")
    enable_booking_rewards_in_stories(@path)

    IO.puts("TASK COMPLETE")
  end

  def enable_booking_rewards_in_stories(path) do
    File.stream!("#{File.cwd!()}/priv/data/#{path}")
    |> CSV.decode(strip_fields: true, headers: true)
    |> Enum.each(fn x -> enable_booking_reward_in_story(x) end)
  end

  def enable_booking_reward_in_story({:ok, data}) do
    user_map = Utils.get_employee_user_map(%{"phone_number" => "cron", "country_code" => "+91"})

    with %Story{} = story <- Stories.get_story(data["Story ID"], [:story_sales_kits, :story_sections]),
         {:ok, _story} <- Stories.update_story(story, %{"is_booking_reward_enabled" => true}, user_map) do
      :ok
    else
      nil ->
        IO.inspect("Story not found: #{data["Story ID"]} ")

      err ->
        IO.inspect("Story_id: #{data["Story ID"]}")
        IO.inspect(err)
    end
  end
end
