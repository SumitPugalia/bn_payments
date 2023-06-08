defmodule Mix.Tasks.AddLegalEntityToStory do
  use Mix.Task

  alias BnApis.Repo
  alias BnApis.Stories.{LegalEntity, StoryLegalEntityMapping}
  alias BnApis.Stories.Story

  @path ["story_to_legal_entity_mapping.csv"]

  @shortdoc "Populate legal entity for story"
  def run(_) do
    Mix.Task.run("app.start", [])

    IO.puts("STARTING TO ADD LEGAL ENTITY TO STORY")

    @path
    |> Enum.each(&populate/1)

    IO.puts("ONE TIMER COMPLETED")
  end

  def populate(path) do
    File.stream!("#{File.cwd!()}/priv/data/#{path}")
    |> CSV.decode(strip_fields: true, headers: true)
    |> Enum.each(fn x -> populate_legal_entity_for_story(x) end)
  end

  def populate_legal_entity_for_story({:error, data}) do
    IO.inspect("============== Error: =============")
    IO.inspect(data)
    nil
  end

  def populate_legal_entity_for_story({:ok, data}) do
    story_id = data["Story Id"] |> parse_to_integer()
    legal_entity_id = data["Legal Entity ID"] |> parse_to_integer()

    story = get_story_id(story_id)
    legal_entity = get_legal_entity_by_id(legal_entity_id)

    valid_story? = not is_nil(story)
    valid_legal_entity? = not is_nil(legal_entity)

    case {valid_story?, valid_legal_entity?} do
      {false, _} ->
        IO.inspect("============== Invalid Story =============")
        IO.inspect("Invalid story_id: #{story_id}")

      {_, false} ->
        IO.inspect("============== Invalid Legal Entity =============")
        IO.inspect("Invalid legal_entity_id: #{legal_entity_id}")

      {true, true} ->
        try do
          StoryLegalEntityMapping.activate_story_legal_entity_mapping(story.id, legal_entity.id)
          IO.inspect("Legal Entity added for story, story_id: #{story.id} and legal_entity_id: #{legal_entity.id}")
        rescue
          error ->
            IO.inspect("============== Error:  =============")
            IO.inspect("Issue while adding legal entity for story, story_id: #{story_id} and legal_entity_id: #{legal_entity_id}")
            IO.inspect(error)
        end
    end
  end

  defp parse_to_integer(nil), do: nil
  defp parse_to_integer(""), do: nil
  defp parse_to_integer(id), do: id |> String.trim() |> String.to_integer()

  defp get_story_id(nil), do: nil
  defp get_story_id(story_id), do: Story |> Repo.get_by(id: story_id)

  defp get_legal_entity_by_id(nil), do: nil
  defp get_legal_entity_by_id(legal_entity_id), do: LegalEntity |> Repo.get_by(id: legal_entity_id)
end
