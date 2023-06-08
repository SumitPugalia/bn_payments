defmodule Mix.Tasks.PopulateStoryTransactionToLegalEntityMapping do
  use Mix.Task

  alias BnApis.Repo
  alias BnApis.Stories.LegalEntity
  alias BnApis.Rewards.StoryTransaction
  alias BnApis.Helpers.Utils

  @path ["story_transaction_legal_entity_mapping.csv"]

  @shortdoc "Populate legal entity for story transaction"
  def run(_) do
    Mix.Task.run("app.start", [])

    IO.puts("STARTING TO UPDATE LEGAL ENTITY FOR STORY TRANSACTION")

    @path
    |> Enum.each(&populate/1)

    IO.puts("ONE TIMER COMPLETED")
  end

  def populate(path) do
    File.stream!("#{File.cwd!()}/priv/data/#{path}")
    |> CSV.decode(strip_fields: true, headers: true)
    |> Enum.each(fn x -> populate_legal_entity_for_story_transaction(x) end)
  end

  def populate_legal_entity_for_story_transaction({:error, data}) do
    IO.inspect("============== Error: =============")
    IO.inspect(data)
    nil
  end

  def populate_legal_entity_for_story_transaction({:ok, data}) do
    story_transaction_id = data["Story Transactions Id"] |> parse_to_integer()
    legal_entity_id = data["Legal Entity ID"] |> parse_to_integer()

    story_transaction = get_story_transaction_by_id(story_transaction_id)
    legal_entity = get_legal_entity_by_id(legal_entity_id)

    valid_story_transaction? = not is_nil(story_transaction)
    valid_legal_entity? = not is_nil(legal_entity)

    case {valid_story_transaction?, valid_legal_entity?} do
      {false, _} ->
        IO.inspect("============== Invalid Story Transaction =============")
        IO.inspect("Invalid story_transaction_id: #{story_transaction_id}")

      {_, false} ->
        IO.inspect("============== Invalid Legal Entity =============")
        IO.inspect("Invalid legal_entity_id: #{legal_entity_id}")

      {true, true} ->
        user_map = Utils.get_employee_user_map(%{"phone_number" => "cron", "country_code" => "+91"})

        with {:ok, story_transaction} <- StoryTransaction.update_legal_entity_id_for_story_transaction(story_transaction, legal_entity.id, user_map) do
          IO.inspect("Legal Entity updated for, story_transaction_id: #{story_transaction.id} and legal_entity_id: #{legal_entity.id}")
        else
          {:error, error} ->
            IO.inspect("============== Error:  =============")
            IO.inspect("Issue while updating legal entity for story transaction, story_transaction_id: #{story_transaction_id} and legal_entity_id: #{legal_entity_id}")
            IO.inspect(error)
        end
    end
  end

  defp parse_to_integer(nil), do: nil
  defp parse_to_integer(""), do: nil
  defp parse_to_integer(id), do: id |> String.trim() |> String.to_integer()

  defp get_story_transaction_by_id(nil), do: nil
  defp get_story_transaction_by_id(story_transaction_id), do: StoryTransaction |> Repo.get_by(id: story_transaction_id)

  defp get_legal_entity_by_id(nil), do: nil
  defp get_legal_entity_by_id(legal_entity_id), do: LegalEntity |> Repo.get_by(id: legal_entity_id)
end
