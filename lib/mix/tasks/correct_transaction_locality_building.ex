defmodule Mix.Tasks.CorrectTransactionLocalityBuilding do
  use Mix.Task
  alias BnApis.Repo
  import Ecto.Query
  alias BnApis.Transactions.Building
  alias BnApis.Transactions.Transaction

  @shortdoc "Correct transactions duplicate locality buildings"
  def run(_) do
    Mix.Task.run("app.start", [])
    # remove first line from csv file that contains headers
    buildings_query()
    |> Enum.each(&duplicate_buildings/1)
  end

  def buildings_query() do
    Building
    |> where([b], not is_nil(b.locality))
    |> group_by([b], [b.place_id, b.name])
    |> select([b], [b.place_id, b.name, fragment("array_agg(?)", b.id)])
    |> order_by([b], fragment("count(*) desc"))
    |> Repo.all()
  end

  def duplicate_buildings([_place_id, _name, building_ids]) do
    case building_ids |> length do
      len when len > 1 ->
        first_building_id = building_ids |> List.first()
        tail_ids = building_ids -- [first_building_id]

        tail_ids
        |> Enum.each(&correct_building_data(&1, first_building_id))

        Building
        |> where([b], b.id in ^tail_ids)
        |> Repo.delete_all()

      _ ->
        IO.puts("No duplicates present!")
    end
  end

  def correct_building_data(building_id, replace_with) do
    Transaction
    |> where([t], t.transaction_building_id == ^building_id)
    |> Ecto.Query.update(set: [transaction_building_id: ^replace_with])
    |> Repo.update_all([])
  end
end
