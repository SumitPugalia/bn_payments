defmodule Mix.Tasks.CorrectStateCodeForLegalEntity do
  use Mix.Task
  import Ecto.Query
  alias BnApis.Repo
  alias BnApis.Stories.LegalEntity

  @state_code_to_place_of_supply_map LegalEntity.get_gst_code_to_place_of_supply_map()

  @shortdoc "Correct state codes for all legal entity data"
  def run(_) do
    Mix.Task.run("app.start", [])
    update_legal_entity_data()
  end

  defp parse_string(nil), do: nil
  defp parse_string(string), do: String.trim(string) |> String.upcase()

  defp get_invalid_legal_entities() do
    LegalEntity
    |> where([le], is_nil(le.state_code))
    |> Repo.all()
  end

  defp get_valid_state_code(place_of_supply) do
    @state_code_to_place_of_supply_map
    |> Map.values()
    |> Enum.filter(fn id ->
      parse_string(id.name) == place_of_supply
    end)
    |> Enum.at(0)
    |> Map.get(:gst)
  end

  defp update_state_code_for_legal_entity(nil), do: nil

  defp update_state_code_for_legal_entity(legal_entity) do
    place_of_supply = legal_entity.place_of_supply |> parse_string()
    valid_state_code = get_valid_state_code(place_of_supply)

    LegalEntity.update_state_code_for_legal_entity(legal_entity, valid_state_code)
    |> case do
      {:ok, le} ->
        IO.inspect("Legal Entity: #{le.id} updated with State Code: #{le.state_code}")

      {:error, error} ->
        IO.inspect("============== Error:  =============")

        IO.inspect("Issue while updating record with Legal Entity Id: #{legal_entity.id} with State Code #{valid_state_code}.")

        IO.inspect(error)
    end
  end

  def update_legal_entity_data() do
    IO.puts("STARTING TO UPDATE OF THE STATE CODES FOR LEGAL ENTITIES")

    invalid_legal_entities = get_invalid_legal_entities()

    Enum.map(invalid_legal_entities, &update_state_code_for_legal_entity/1)

    IO.puts("UPDATE COMPLETE")
  end
end
